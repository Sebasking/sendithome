defmodule ShipperDirectory.Placements do
  @moduledoc """
  Sponsored placements (spec section 9.1). Sponsored companies show in a
  labeled "Sponsored" block above the organic results on matching route
  pages and searches, and are left out of the organic list below so
  nobody appears twice.
  """

  alias ShipperDirectory.Directory

  @doc "Sponsored companies for a metro (and optional destination) today, deduplicated."
  def sponsored(nil, _destination), do: []

  def sponsored(metro, destination) do
    metro
    |> Directory.active_placements!(destination, Date.utc_today())
    |> Enum.map(& &1.company)
    # A metro-wide sponsor only shows on routes it actually serves.
    |> Enum.filter(&(is_nil(destination) or destination in &1.destination_slugs))
    |> Enum.uniq_by(& &1.id)
  end

  @doc "Splits results into {sponsored, organic}."
  def split(companies, metro, destination) do
    sponsored = sponsored(metro, destination)
    ids = MapSet.new(sponsored, & &1.id)
    {sponsored, Enum.reject(companies, &MapSet.member?(ids, &1.id))}
  end
end
