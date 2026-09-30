defmodule ShipperDirectory.Directory.Import.SeedCsv do
  @moduledoc """
  Imports `shipper_seed_list.csv` (columns: name, hq_or_origin, destinations,
  website, presence_status, source, notes).

  Goes through `Directory.Ingest`, so a rerun makes no new companies. It
  only fills blank fields and unions list fields. Each row is also kept as
  a `seed_csv` Sighting.

  The CSV's `presence_status` column is a hint, not a verdict:
    * `listed`: status `discovered`. The presence checker publishes it once verified.
    * `verify`: held in the review queue with the CSV note as the reason.
    * `prospect`: status `prospect`, presence `none` when there's no URL.
  """

  alias ShipperDirectory.Directory.{Ingest, Normalize}

  @source "seed_csv"
  @phone_regex ~r/\(\d{3}\)\s*\d{3}-\d{4}/

  def default_path, do: Application.app_dir(:shipper_directory, "priv/seed/shipper_seed_list.csv")

  @doc "Returns `%{created: n, updated: n}`."
  def import!(path \\ default_path()) do
    path
    |> File.read!()
    |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
    |> to_maps()
    |> Enum.reduce(%{created: 0, updated: 0}, fn row, acc ->
      {result, _company} = import_row!(row)
      Map.update!(acc, result, &(&1 + 1))
    end)
  end

  def import_row!(row) do
    row |> row_to_attrs() |> Ingest.ingest!(@source, Normalize.slug(row["name"]), row)
  end

  def row_to_attrs(row) do
    location = parse_location(row["hq_or_origin"])
    website = blank_to_nil(row["website"])
    notes = blank_to_nil(row["notes"])

    phone =
      case Regex.run(@phone_regex, notes || "") do
        [match] -> match
        _ -> nil
      end

    base = %{
      name: String.trim(row["name"]),
      phone: phone,
      website_url: website,
      destinations: parse_destinations(row["destinations"]),
      source: Enum.uniq([@source | List.wrap(blank_to_nil(row["source"]))]),
      notes: notes
    }

    base
    |> Map.merge(location)
    |> Map.merge(status_attrs(String.trim(row["presence_status"] || ""), website, notes))
  end

  defp status_attrs("verify", _website, notes) do
    %{
      status: :discovered,
      presence_status: :needs_review,
      hold_for_review: true,
      review_reason: "Seed list flagged for verification: #{notes}"
    }
  end

  defp status_attrs("prospect", nil, _notes), do: %{status: :prospect, presence_status: :none}
  defp status_attrs("prospect", _website, _notes), do: %{status: :prospect}
  defp status_attrs(_listed, _website, _notes), do: %{status: :discovered}

  @doc """
  Splits "35 Rogers Ave, Brooklyn, NY" into address/city/state, and
  "Miami / Fort Lauderdale, FL" into origin metros. Parenthetical remarks
  ("(earlier Brooklyn)") are dropped. The raw value stays in the Sighting.
  """
  def parse_location(nil), do: %{origin_metros: []}

  def parse_location(value) do
    parts =
      value
      |> String.replace(~r/\(.*?\)/, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case Enum.reverse(parts) do
      [state, city_part | address] ->
        if state =~ ~r/^[A-Z]{2}$/ do
          metros = split_metros(city_part)

          %{
            address: address |> Enum.reverse() |> Enum.join(", ") |> blank_to_nil(),
            city: List.first(metros),
            state: state,
            origin_metros: metros
          }
        else
          %{origin_metros: split_metros(value)}
        end

      _ ->
        %{origin_metros: split_metros(value)}
    end
  end

  defp split_metros(value) do
    value
    |> String.split(~r/\s*[\/+]\s*/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.downcase(&1) in ["", "unknown", "other", "multi-office"]))
  end

  def parse_destinations(nil), do: []

  def parse_destinations(value) do
    value
    |> String.split(~r/\s*[,+]\s*/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.downcase(&1) in ["", "more"]))
  end

  defp to_maps([headers | rows]) do
    headers = Enum.map(headers, &String.trim/1)
    Enum.map(rows, &(headers |> Enum.zip(&1) |> Map.new()))
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
