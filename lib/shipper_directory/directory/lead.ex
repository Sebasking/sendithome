defmodule ShipperDirectory.Directory.Lead do
  @moduledoc """
  A consumer's quote request. It goes only to the shippers the consumer
  picked (see `ShipperDirectory.Leads`), and `consent_text` stores exactly
  what they agreed to, naming those shippers.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  alias ShipperDirectory.Directory.Normalize
  alias ShipperDirectory.Directory.Types.{DestinationSlug, Metro}

  postgres do
    table "leads"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :name,
        :email,
        :phone,
        :origin_metro,
        :destination,
        :barrels,
        :boxes,
        :other_items,
        :pickup_needed,
        :ship_by,
        :notes,
        :consent_text,
        :source_path
      ]

      change set_attribute(:consented_at, &DateTime.utc_now/0)
    end

    read :recent do
      prepare build(sort: [inserted_at: :desc], limit: 200, load: [deliveries: [:company]])
    end

    read :recent_from_contact do
      argument :email, :ci_string
      argument :phone, :string
      argument :since, :utc_datetime_usec, allow_nil?: false

      filter expr(
               inserted_at > ^arg(:since) and
                 ((not is_nil(^arg(:email)) and email == ^arg(:email)) or
                    (not is_nil(^arg(:phone)) and normalized_phone == ^arg(:phone)))
             )
    end
  end

  changes do
    change fn changeset, _context ->
             phone = Ash.Changeset.get_attribute(changeset, :phone)

             Ash.Changeset.force_change_attribute(
               changeset,
               :normalized_phone,
               Normalize.phone(phone)
             )
           end,
           on: [:create]
  end

  validations do
    validate present([:email, :phone], at_least: 1),
      message: "Enter an email or a phone number so shippers can reach you"

    validate numericality(:barrels, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    validate numericality(:boxes, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :email, :ci_string, public?: true
    attribute :phone, :string, public?: true
    attribute :normalized_phone, :string
    attribute :origin_metro, Metro, allow_nil?: false, public?: true
    attribute :destination, DestinationSlug, allow_nil?: false, public?: true
    attribute :barrels, :integer, allow_nil?: false, default: 0, public?: true
    attribute :boxes, :integer, allow_nil?: false, default: 0, public?: true
    attribute :other_items, :string, public?: true
    attribute :pickup_needed, :boolean, allow_nil?: false, default: false, public?: true
    attribute :ship_by, :date, public?: true
    attribute :notes, :string, public?: true
    attribute :consent_text, :string, allow_nil?: false, public?: true
    attribute :consented_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :source_path, :string, public?: true
    timestamps()
  end

  relationships do
    has_many :deliveries, ShipperDirectory.Directory.LeadDelivery
  end
end
