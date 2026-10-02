defmodule ShipperDirectory.Directory.Validations.PlacementSlotAvailable do
  @moduledoc """
  A slot (metro + destination) can't have more than `max` placements
  overlapping in time, and a company can't hold two overlapping placements
  in the same slot. A metro-wide placement counts against every route from
  that metro.
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias ShipperDirectory.Directory.Placement

  @impl true
  def validate(changeset, opts, _context) do
    get = &Ash.Changeset.get_attribute(changeset, &1)

    {metro, destination, from, to} =
      {get.(:metro), get.(:destination), get.(:starts_on), get.(:ends_on)}

    if Enum.any?([metro, from, to], &is_nil/1) do
      :ok
    else
      overlapping =
        Placement
        |> Ash.Query.filter(metro == ^metro and starts_on <= ^to and ends_on >= ^from)
        |> Ash.read!()
        |> Enum.filter(
          &(is_nil(destination) or is_nil(&1.destination) or &1.destination == destination)
        )

      cond do
        Enum.any?(overlapping, &(&1.company_id == get.(:company_id))) ->
          {:error,
           field: :company_id, message: "already has a placement in this slot for these dates"}

        length(overlapping) >= opts[:max] ->
          {:error,
           field: :destination, message: "slot is full for these dates (max #{opts[:max]})"}

        true ->
          :ok
      end
    end
  end
end
