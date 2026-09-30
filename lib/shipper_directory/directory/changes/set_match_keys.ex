defmodule ShipperDirectory.Directory.Changes.SetMatchKeys do
  @moduledoc """
  Keeps `normalized_phone` and `name_key` in sync with the contact fields.
  On create it also sets `slug` and `dedupe_key`. Those two are not changed
  on update, so URLs and the dedupe identity stay stable after an edit.
  """
  use Ash.Resource.Change

  alias ShipperDirectory.Directory.Normalize

  @impl true
  def change(changeset, _opts, _context) do
    get = &Ash.Changeset.get_attribute(changeset, &1)
    phone = Normalize.phone(get.(:phone))
    name_key = Normalize.name_key(get.(:name), get.(:address), get.(:city), get.(:state))

    changeset =
      changeset
      |> Ash.Changeset.force_change_attribute(:normalized_phone, phone)
      |> Ash.Changeset.force_change_attribute(:name_key, name_key)
      |> Ash.Changeset.force_change_attribute(:name_core, Normalize.name_core(get.(:name)))

    if changeset.action_type == :create do
      changeset
      |> Ash.Changeset.force_change_attribute(:dedupe_key, Normalize.dedupe_key(phone, name_key))
      |> Ash.Changeset.force_change_attribute(:slug, get.(:slug) || Normalize.slug(get.(:name)))
    else
      changeset
    end
  end
end
