defmodule ShipperDirectory.Directory.Sighting do
  @moduledoc """
  The raw record for one company from one source (seed CSV, Google Places,
  Yelp, FMC, ...). Re-importing the same source record updates it in place.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sightings"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :record do
      accept [:source, :external_id, :raw_payload, :company_id]
      upsert? true
      upsert_identity :unique_source_record
      upsert_fields [:raw_payload, :company_id, :updated_at]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :source, :string, allow_nil?: false, public?: true
    attribute :external_id, :string, allow_nil?: false, public?: true
    attribute :raw_payload, :map, allow_nil?: false, default: %{}, public?: true
    timestamps()
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company do
      allow_nil? false
    end
  end

  identities do
    identity :unique_source_record, [:source, :external_id]
  end
end
