defmodule ShipperDirectory.Discovery.Metros do
  @moduledoc """
  Origin metros we discover shippers in, by ZIP prefix. FMC's city field is
  inconsistent. Queens licensees say "JAMAICA", "ROSEDALE", "SPRINGFIELD
  GARDENS", so ZIP prefixes are more reliable. NYC first (per the spec),
  then NJ, CT, FL, Boston.
  """

  # `aliases` are lowercase city/area names seen in company records.
  @metros [
    %{slug: "brooklyn", name: "Brooklyn", state: "NY", zips: ~w(112), aliases: ["brooklyn"]},
    %{
      slug: "queens",
      name: "Queens",
      state: "NY",
      zips: ~w(110 111 113 114 116),
      aliases: [
        "queens",
        "jamaica",
        "rosedale",
        "springfield gardens",
        "queens village",
        "cambria heights",
        "ozone park",
        "richmond hill",
        "south ozone park",
        "laurelton",
        "st. albans",
        "saint albans",
        "hollis",
        "flushing",
        "far rockaway"
      ]
    },
    %{slug: "bronx", name: "Bronx", state: "NY", zips: ~w(104), aliases: ["bronx", "the bronx"]},
    %{
      slug: "manhattan",
      name: "Manhattan",
      state: "NY",
      zips: ~w(100 101 102),
      aliases: ["manhattan", "harlem"]
    },
    %{
      slug: "staten-island",
      name: "Staten Island",
      state: "NY",
      zips: ~w(103),
      aliases: ["staten island"]
    },
    %{
      slug: "north-jersey",
      name: "North Jersey",
      state: "NJ",
      zips: ~w(070 071 072 073 074 075),
      aliases: [
        "newark",
        "east orange",
        "orange",
        "irvington",
        "jersey city",
        "elizabeth",
        "paterson",
        "plainfield",
        "montclair",
        "nj"
      ]
    },
    %{
      slug: "connecticut",
      name: "Connecticut",
      state: "CT",
      zips: ~w(060 061 064 065 066 068 069),
      aliases: ["bridgeport", "hartford", "stamford", "norwalk", "new haven", "waterbury"]
    },
    %{
      slug: "miami",
      name: "Miami",
      state: "FL",
      zips: ~w(330 331 332),
      aliases: ["miami", "miami gardens", "north miami", "hialeah", "doral", "opa-locka"]
    },
    %{
      slug: "broward",
      name: "Fort Lauderdale",
      state: "FL",
      zips: ~w(333),
      aliases: [
        "fort lauderdale",
        "ft. lauderdale",
        "lauderhill",
        "lauderdale lakes",
        "sunrise",
        "plantation",
        "miramar",
        "pembroke pines",
        "hollywood",
        "tamarac",
        "margate",
        "pompano beach"
      ]
    },
    %{
      slug: "palm-beach",
      name: "Palm Beach",
      state: "FL",
      zips: ~w(334),
      aliases: ["west palm beach", "palm beach", "boca raton", "delray beach", "boynton beach"]
    },
    %{
      slug: "orlando",
      name: "Orlando",
      state: "FL",
      zips: ~w(327 328 347),
      aliases: ["orlando", "kissimmee"]
    },
    %{
      slug: "boston",
      name: "Boston",
      state: "MA",
      zips: ~w(021 022 024),
      aliases: [
        "boston",
        "dorchester",
        "mattapan",
        "roxbury",
        "hyde park",
        "randolph",
        "brockton"
      ]
    }
  ]

  @nyc ~w(brooklyn queens bronx manhattan staten-island)

  def all, do: @metros
  def slugs, do: Enum.map(@metros, & &1.slug)
  def nyc, do: @nyc
  def states, do: @metros |> Enum.map(& &1.state) |> Enum.uniq()

  def get(slug), do: Enum.find(@metros, &(&1.slug == slug))

  def name(slug) do
    case get(slug) do
      nil -> nil
      metro -> metro.name
    end
  end

  @doc """
  Metro slugs for free-text places ("Lauderhill", "Miami / Fort Lauderdale").
  "Jamaica" only counts as Queens when the state is NY, because it's also a
  destination.
  """
  def slugs_for(places, state) do
    places
    |> Enum.map(&(&1 |> String.downcase() |> String.trim()))
    |> Enum.reject(&(&1 == "jamaica" and state != "NY"))
    |> Enum.flat_map(fn place -> Enum.filter(@metros, &Enum.member?(&1.aliases, place)) end)
    |> Enum.map(& &1.slug)
    |> Enum.uniq()
  end

  @doc "The metro a US address falls in, or nil."
  def for_address(state, zip) when is_binary(state) and is_binary(zip) do
    zip = String.pad_leading(String.trim(zip), 5, "0")
    Enum.find(@metros, &(&1.state == state and String.starts_with?(zip, &1.zips)))
  end

  def for_address(_state, _zip), do: nil
end
