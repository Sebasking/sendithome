defmodule ShipperDirectory.Directory.Changes.SetSearchKeys do
  @moduledoc """
  Derives `metro_slugs` and `destination_slugs` from the free-text
  origin_metros/city/state and destinations, for search and the SEO route
  pages.
  """
  use Ash.Resource.Change

  alias ShipperDirectory.Directory.Destinations
  alias ShipperDirectory.Discovery.Metros

  @impl true
  def change(changeset, _opts, _context) do
    get = &Ash.Changeset.get_attribute(changeset, &1)
    places = Enum.reject([get.(:city) | get.(:origin_metros) || []], &is_nil/1)

    changeset
    |> Ash.Changeset.force_change_attribute(:metro_slugs, Metros.slugs_for(places, get.(:state)))
    |> Ash.Changeset.force_change_attribute(
      :destination_slugs,
      Destinations.slugs_for(get.(:destinations) || [])
    )
  end
end
