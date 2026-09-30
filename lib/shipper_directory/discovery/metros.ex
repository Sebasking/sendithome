defmodule ShipperDirectory.Discovery.Metros do
  @moduledoc """
  Origin metros we discover shippers in, by ZIP prefix. FMC's city field is
  inconsistent. Queens licensees say "JAMAICA", "ROSEDALE", "SPRINGFIELD
  GARDENS", so ZIP prefixes are more reliable. NYC first (per the spec),
  then NJ, CT, FL, Boston.
  """

  @metros [
    %{slug: "brooklyn", name: "Brooklyn", state: "NY", zips: ~w(112)},
    %{slug: "queens", name: "Queens", state: "NY", zips: ~w(110 111 113 114 116)},
    %{slug: "bronx", name: "Bronx", state: "NY", zips: ~w(104)},
    %{slug: "manhattan", name: "Manhattan", state: "NY", zips: ~w(100 101 102)},
    %{slug: "staten-island", name: "Staten Island", state: "NY", zips: ~w(103)},
    %{slug: "north-jersey", name: "North Jersey", state: "NJ", zips: ~w(070 071 072 073 074 075)},
    %{
      slug: "connecticut",
      name: "Connecticut",
      state: "CT",
      zips: ~w(060 061 064 065 066 068 069)
    },
    %{slug: "miami", name: "Miami", state: "FL", zips: ~w(330 331 332)},
    %{slug: "broward", name: "Fort Lauderdale", state: "FL", zips: ~w(333)},
    %{slug: "palm-beach", name: "Palm Beach", state: "FL", zips: ~w(334)},
    %{slug: "orlando", name: "Orlando", state: "FL", zips: ~w(327 328 347)},
    %{slug: "boston", name: "Boston", state: "MA", zips: ~w(021 022 024)}
  ]

  @nyc ~w(brooklyn queens bronx manhattan staten-island)

  def all, do: @metros
  def slugs, do: Enum.map(@metros, & &1.slug)
  def nyc, do: @nyc
  def states, do: @metros |> Enum.map(& &1.state) |> Enum.uniq()

  def get(slug), do: Enum.find(@metros, &(&1.slug == slug))

  @doc "The metro a US address falls in, or nil."
  def for_address(state, zip) when is_binary(state) and is_binary(zip) do
    zip = String.pad_leading(String.trim(zip), 5, "0")
    Enum.find(@metros, &(&1.state == state and String.starts_with?(zip, &1.zips)))
  end

  def for_address(_state, _zip), do: nil
end
