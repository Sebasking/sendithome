defmodule ShipperDirectory.Directory.Placement do
  @moduledoc """
  A paid, clearly labeled "Sponsored" slot for a published company: on one
  route (metro + destination), or on every route from a metro when
  `destination` is nil. At most `max_per_slot` overlapping placements can
  share a slot.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  alias ShipperDirectory.Directory.Destinations
  alias ShipperDirectory.Discovery.Metros

  @max_per_slot 2
  def max_per_slot, do: @max_per_slot

  postgres do
    table "placements"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:company_id, :metro, :destination, :starts_on, :ends_on, :price_cents, :notes]
      validate compare(:ends_on, greater_than_or_equal_to: :starts_on)
      validate {ShipperDirectory.Directory.Validations.PlacementSlotAvailable, max: @max_per_slot}
    end

    update :end_now do
      change set_attribute(:ends_on, &Date.utc_today/0)
    end

    read :active_for do
      description "Placements live today for a metro; with a destination, only that route's (plus metro-wide)."
      argument :metro, :string, allow_nil?: false
      argument :destination, :string
      argument :on, :date, allow_nil?: false

      filter expr(
               metro == ^arg(:metro) and starts_on <= ^arg(:on) and ends_on >= ^arg(:on) and
                 (is_nil(^arg(:destination)) or is_nil(destination) or
                    destination == ^arg(:destination)) and
                 company.status == :published
             )

      prepare build(sort: [:starts_on], load: [:company])
    end

    read :listing do
      prepare build(sort: [ends_on: :desc], load: [:company])
    end
  end

  validations do
    validate one_of(:metro, Metros.slugs())

    validate one_of(:destination, Destinations.slugs()),
      where: present(:destination)
  end

  attributes do
    uuid_primary_key :id
    attribute :metro, :string, allow_nil?: false, public?: true
    # nil = every route from the metro
    attribute :destination, :string, public?: true
    attribute :starts_on, :date, allow_nil?: false, public?: true
    attribute :ends_on, :date, allow_nil?: false, public?: true
    attribute :price_cents, :integer, allow_nil?: false, default: 0, public?: true
    attribute :notes, :string, public?: true
    timestamps()
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company, allow_nil?: false
  end
end
