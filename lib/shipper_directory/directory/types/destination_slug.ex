defmodule ShipperDirectory.Directory.Types.DestinationSlug do
  @moduledoc "A canonical destination slug (`trinidad-and-tobago`), from `Destinations`. Values stay strings."
  alias ShipperDirectory.Directory.Destinations

  use Ash.Type.Enum, values: Destinations.slugs()

  @impl true
  def label(slug), do: Destinations.name(slug)

  # Name the valid slugs instead of Ash's bare "is invalid".
  @impl true
  def match(value) do
    with :error <- super(value) do
      {:error, message: "must be one of: " <> Enum.join(Destinations.slugs(), ", ")}
    end
  end
end
