defmodule ShipperDirectory.Discovery.Fmc do
  @moduledoc """
  The FMC's list of licensed & bonded Ocean Transportation Intermediaries
  (NVOCCs and freight forwarders). It's public government data, so unlike
  Google/Yelp content it can be stored.

  Source: the "download the list of all active freight forwarders and
  NVOCCs" button on https://www2.fmc.gov/oti/NVOCC.aspx, an ASP.NET postback
  that returns an .xlsx. Row 1 is "List as of: <timestamp>", row 2 has the
  headers (Organization Number, Name, Street 1, Street 2, City, State, Zip,
  Nation, Phone, ..., License Number, ..., NVOCC/FF DBA Name 1/2).

  `import!/2` does two things:
    1. Cross-reference: every existing company that matches a licensee by
       phone or exact normalized name (including DBAs) gets the license number.
    2. Discovery: every licensee in the requested metros becomes a company.
       Names with a Caribbean keyword are auto-confirmed. The rest go to the
       triage queue, because many Caribbean shippers ("Dennis Shipping",
       "Trans-Jam") can't be recognized by name.
  """

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Destinations, Ingest, Normalize}
  alias ShipperDirectory.Discovery.Metros

  @source "fmc"
  @list_url "https://www2.fmc.gov/oti/NVOCC.aspx"
  @tiers ~w(A B C D)

  @caribbean_regex ~r/\b(caribb\w*|carib\w*|jamaica\w*|trans-?jam|guyan\w*|trinidad|tobago|t\s?&\s?t|barbad\w*|bajan|st\.? lucia|saint lucia|grenad\w*|haiti\w*|dominica\w*|antigua\w*|st\.? vincent|vincy|st\.? kitts|nevis|bahama\w*|surinam\w*|belize\w*|islands?|barrels?|west indi\w*|antilles|montserrat|anguilla|cayman|virgin islands)\b/i

  @not_caribbean_islands ~r/\b(long|staten|rhode|coney|shelter|marco|amelia|merritt|key)\s+island\b/i

  @doc "Downloads the current list. Returns the .xlsx binary."
  def download!(req_options \\ []) do
    req = Req.new([headers: [user_agent: "Mozilla/5.0 (ShipperDirectory)"]] ++ req_options)

    page_resp = Req.get!(req, url: @list_url)
    {:ok, doc} = Floki.parse_document(page_resp.body)

    form =
      doc
      |> Floki.find("input[type=hidden]")
      |> Enum.map(fn input ->
        {input |> Floki.attribute("name") |> List.first(),
         input |> Floki.attribute("value") |> List.first() || ""}
      end)
      |> Enum.filter(fn {name, _} ->
        name in ~w(__VIEWSTATE __VIEWSTATEGENERATOR __EVENTVALIDATION)
      end)
      |> Enum.concat([{"ctl00$buttonOTIListDownload", "Download"}])

    # The postback redirects to a Location with unencoded spaces, which Req
    # rejects, so the redirect is followed by hand with the session cookie.
    post_resp =
      Req.post!(req,
        url: @list_url,
        form: form,
        redirect: false,
        headers: [cookie: cookies(page_resp)]
      )

    resp =
      case post_resp do
        %{status: status} when status in 300..399 ->
          location = post_resp |> Req.Response.get_header("location") |> List.first()

          Req.get!(req,
            url: @list_url |> URI.merge(URI.encode(location)) |> URI.to_string(),
            headers: [cookie: cookies(page_resp) <> "; " <> cookies(post_resp)],
            receive_timeout: 120_000
          )

        other ->
          other
      end

    case resp do
      %{status: 200, body: <<"PK", _::binary>> = body} -> body
      %{status: status} -> raise "FMC download failed: HTTP #{status}, not an .xlsx"
    end
  end

  defp cookies(resp) do
    resp
    |> Req.Response.get_header("set-cookie")
    |> Enum.map_join("; ", &(&1 |> String.split(";") |> List.first()))
  end

  @doc "Parses the .xlsx (binary or path) into maps keyed by header name."
  def parse!(xlsx, source \\ :binary) do
    {:ok, package} = XlsxReader.open(xlsx, source: source)
    {:ok, [{_name, rows} | _]} = XlsxReader.sheets(package)
    parse_rows(rows)
  end

  @doc "Skips the \"List as of\" banner, zips the header row onto each data row."
  def parse_rows(rows) do
    [headers | data] = Enum.drop_while(rows, &(List.first(&1) != "Organization Number"))
    headers = Enum.map(headers, &String.trim/1)

    Enum.map(data, fn row ->
      headers |> Enum.zip(Enum.map(row, &cell/1)) |> Map.new()
    end)
  end

  defp cell(value) when is_binary(value), do: String.trim(value)
  defp cell(value) when is_float(value), do: value |> trunc() |> Integer.to_string()
  defp cell(nil), do: ""
  defp cell(value), do: to_string(value)

  @doc """
  Cross-references and discovers. Options:
    * `:metros`: metro slugs to discover in (default: NYC boroughs). Pass
      `Metros.slugs()` for every metro.
  Returns stats.
  """
  def import!(records, opts \\ []) do
    metros = Keyword.get(opts, :metros, Metros.nyc())
    us = Enum.filter(records, &(&1["Nation"] == "UNITED STATES"))

    linked = cross_reference!(us)

    discovered =
      us
      |> Enum.map(&{&1, Metros.for_address(&1["State"], &1["Zip"])})
      |> Enum.filter(fn {_row, metro} -> metro && metro.slug in metros end)
      |> Enum.map(fn {row, metro} -> discover!(row, metro) end)

    %{
      "linked" => linked,
      "created" => Enum.count(discovered, &match?({:created, _}, &1)),
      "updated" => Enum.count(discovered, &match?({:updated, _}, &1)),
      "auto_confirmed" =>
        Enum.count(discovered, fn {r, c} -> r == :created and not c.needs_triage end),
      "metros" => metros
    }
  end

  @doc """
  Imports a scored copy of the list: the OTI columns plus `tier` ("A_strong",
  "B_likely_area", "C_weak", "D_none") and `kw_dest`. Every US licensee at
  `:min_tier` (default "B") or better becomes a company, in any metro. The
  scoring already judged them Caribbean shippers, so they skip triage.
  Returns stats.
  """
  def import_scored!(records, opts \\ []) do
    min_tier = opts |> Keyword.get(:min_tier, "B") |> String.upcase()

    unless min_tier in @tiers,
      do: raise(ArgumentError, "min_tier must be one of #{Enum.join(@tiers, ", ")}")

    selected =
      Enum.filter(records, fn row ->
        row["Nation"] == "UNITED STATES" and
          tier(row) in Enum.take_while(@tiers, &(&1 <= min_tier))
      end)

    linked = cross_reference!(selected)

    discovered =
      Enum.map(selected, fn row ->
        metro = Metros.for_address(row["State"], row["Zip"])

        row
        |> fmc_attrs()
        |> Map.merge(%{
          origin_metros: if(metro, do: [metro.name], else: []),
          destinations: scored_destinations(row["kw_dest"]),
          status: :discovered,
          needs_triage: false
        })
        |> Ingest.ingest!(@source, row["Organization Number"], row)
      end)

    %{
      "selected" => length(selected),
      "linked" => linked,
      "created" => Enum.count(discovered, &match?({:created, _}, &1)),
      "updated" => Enum.count(discovered, &match?({:updated, _}, &1)),
      "min_tier" => min_tier
    }
  end

  defp tier(row),
    do: row |> Map.get("tier", "") |> String.first() |> to_string() |> String.upcase()

  # "ANTIGUA;ST. KITTS;CAICOS" -> ["Antigua & Barbuda", "St. Kitts & Nevis", "Caicos"]
  defp scored_destinations(nil), do: []

  defp scored_destinations(kw_dest) do
    kw_dest
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn value ->
      case Destinations.slugs_for([value]) do
        [slug] -> Destinations.name(slug)
        [] -> value |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
      end
    end)
    |> Enum.uniq()
  end

  @doc "Adds license numbers to existing companies that match a licensee. Returns the count."
  def cross_reference!(records) do
    by_phone =
      for row <- records, phone = Normalize.phone(row["Phone"]), into: %{}, do: {phone, row}

    by_name =
      for row <- records, name <- names(row), into: %{}, do: {Normalize.name(name), row}

    Directory.list_companies!()
    |> Enum.filter(&is_nil(&1.fmc_license_no))
    |> Enum.reduce(0, fn company, count ->
      row = by_phone[company.normalized_phone] || by_name[Normalize.name(company.name)]

      if row && row["License Number"] != "" do
        Ingest.attach!(company, fmc_attrs(row), @source, row["Organization Number"], row)
        count + 1
      else
        count
      end
    end)
  end

  defp discover!(row, metro) do
    attrs =
      row
      |> fmc_attrs()
      |> Map.merge(%{
        origin_metros: [metro.name],
        status: :discovered,
        needs_triage: not caribbean_name?(row)
      })

    Ingest.ingest!(attrs, @source, row["Organization Number"], row)
  end

  def caribbean_name?(row) do
    row
    |> names()
    |> Enum.map(&String.replace(&1, @not_caribbean_islands, ""))
    |> Enum.any?(&Regex.match?(@caribbean_regex, &1))
  end

  defp names(row) do
    [
      row["Name"],
      row["NVOCC DBA Name 1"],
      row["NVOCC DBA Name 2"],
      row["FF DBA Name 1"],
      row["FF DBA Name 2"]
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp fmc_attrs(row) do
    %{
      name: title_case(row["Name"]),
      address:
        [row["Street 1"], row["Street 2"]]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(", ")
        |> title_case(),
      city: title_case(row["City"]),
      state: row["State"],
      phone: row["Phone"],
      fmc_license_no: blank_to_nil(row["License Number"]),
      source: [@source],
      notes: dba_note(row)
    }
  end

  defp dba_note(row) do
    case row |> names() |> tl() |> Enum.uniq() do
      [] -> nil
      dbas -> "DBA: " <> Enum.join(dbas, ", ")
    end
  end

  # "D.A.D. CARIBBEAN SHIPPING CO., INC." -> "D.A.D. Caribbean Shipping Co., Inc."
  # Initialisms stay upper case: dotted ("D.A.D."), with "&" ("T&T"), or up to 3 letters ("LLC", "USG").
  defp title_case(""), do: nil
  defp title_case(nil), do: nil

  defp title_case(value) do
    value
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &title_case_word/1)
  end

  defp title_case_word(word) do
    bare = word |> String.downcase() |> String.trim_trailing(",")

    cond do
      bare in ~w(and of the) ->
        String.downcase(word)

      bare in ~w(inc. co. corp. ltd. ltd co inc corp) ->
        String.capitalize(word)

      String.length(String.replace(bare, ~r/[^a-z0-9]/, "")) <= 3 or
          String.contains?(bare, [".", "&"]) ->
        word

      true ->
        word |> String.downcase() |> String.split("-") |> Enum.map_join("-", &String.capitalize/1)
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
