defmodule ShipperDirectory.Directory.RoutePages do
  @moduledoc """
  SEO route pages like `/ship-barrel/brooklyn-to-guyana`: one per
  (origin metro, destination) pair that at least one published company
  serves. Pairs with no companies don't exist (no thin pages).
  """

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Destinations
  alias ShipperDirectory.Discovery.Metros

  @doc "Every route with at least one published company, most-served first."
  def available do
    Directory.published_companies!()
    |> Enum.flat_map(fn c -> for m <- c.metro_slugs, d <- c.destination_slugs, do: {m, d} end)
    |> Enum.frequencies()
    |> Enum.map(fn {{metro, destination}, count} -> build(metro, destination, count) end)
    |> Enum.sort_by(&{-&1.count, &1.metro_name, &1.destination_name})
  end

  @doc "Parses \"brooklyn-to-guyana\" into known metro and destination slugs."
  def parse(route) do
    with [metro, destination] <- String.split(route, "-to-", parts: 2),
         %{} <- Metros.get(metro),
         name when is_binary(name) <- Destinations.name(destination) do
      {:ok, metro, destination}
    else
      _ -> :error
    end
  end

  def slug(metro, destination), do: "#{metro}-to-#{destination}"

  def build(metro, destination, count \\ nil) do
    %{
      slug: slug(metro, destination),
      metro: metro,
      destination: destination,
      metro_name: Metros.name(metro),
      destination_name: Destinations.name(destination),
      count: count
    }
  end
end
