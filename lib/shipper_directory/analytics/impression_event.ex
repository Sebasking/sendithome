defmodule ShipperDirectory.Analytics.ImpressionEvent do
  @moduledoc "A shipper shown on a QR flow results page. `sponsored` marks the featured card."
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "impression_events"
    repo ShipperDirectory.Repo

    references do
      reference :company, on_delete: :nilify
    end

    custom_indexes do
      index [:inserted_at]
      index [:company_id]
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:company_id, :sponsored, :destination_code, :area_slug, :source_code]
    end

    destroy :expire do
      description "Retention job only."
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :sponsored, :boolean, allow_nil?: false, default: false, public?: true
    attribute :destination_code, :string, public?: true
    attribute :area_slug, :string, public?: true
    attribute :source_code, :string, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company, public?: true
  end
end
