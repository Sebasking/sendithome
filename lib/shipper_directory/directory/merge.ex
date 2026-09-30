defmodule ShipperDirectory.Directory.Merge do
  @moduledoc """
  Merges a duplicate company into the one being kept. Sightings, presence
  checks, and outreach events move over. Blank fields are filled and list
  fields unioned (same rules as `Ingest`). Then the duplicate is deleted.
  """

  import Ecto.Query

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Company, Ingest}
  alias ShipperDirectory.Repo

  @child_tables ~w(sightings presence_checks outreach_events)
  @mergeable_fields [
    :phone,
    :email,
    :address,
    :city,
    :state,
    :website_url,
    :fmc_license_no,
    :notes,
    :source,
    :origin_metros,
    :destinations
  ]

  def merge!(%Company{id: id}, %Company{id: id}),
    do: raise(ArgumentError, "can't merge a company into itself")

  def merge!(%Company{} = keep, %Company{} = duplicate) do
    Repo.transaction(fn ->
      keep_id = Ecto.UUID.dump!(keep.id)
      dup_id = Ecto.UUID.dump!(duplicate.id)

      for table <- @child_tables do
        Repo.update_all(from(t in table, where: t.company_id == ^dup_id),
          set: [company_id: keep_id]
        )
      end

      Repo.update_all(
        from(c in "companies",
          where: c.possible_duplicate_of_id == ^dup_id and c.id != ^keep_id
        ),
        set: [possible_duplicate_of_id: keep_id]
      )

      kept = Ingest.merge!(keep, Map.take(duplicate, @mergeable_fields))

      kept =
        case {kept.google_place_id, duplicate.google_place_id} do
          {nil, place_id} when is_binary(place_id) ->
            Directory.record_google!(kept, %{
              google_place_id: place_id,
              google_has_website: duplicate.google_has_website,
              google_checked_at: duplicate.google_checked_at
            })

          _ ->
            kept
        end

      kept =
        if kept.possible_duplicate_of_id == duplicate.id,
          do: Directory.dismiss_duplicate!(kept),
          else: kept

      Ash.destroy!(duplicate)
      kept
    end)
    |> case do
      {:ok, kept} -> kept
      {:error, reason} -> raise "merge failed: #{inspect(reason)}"
    end
  end
end
