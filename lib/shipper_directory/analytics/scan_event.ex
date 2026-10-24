defmodule ShipperDirectory.Analytics.ScanEvent do
  @moduledoc "A sticker QR scan (`/s/:code`, or the legacy `/?utm_source=sticker`)."
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "scan_events"
    repo ShipperDirectory.Repo

    custom_indexes do
      index [:inserted_at]
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:source_code, :utm_source, :utm_medium, :utm_campaign, :utm_content]
    end

    destroy :expire do
      description "Retention job only."
    end
  end

  attributes do
    uuid_primary_key :id
    # The raw code from the URL, even when it matches no sticker source.
    attribute :source_code, :string, public?: true
    attribute :utm_source, :string, public?: true
    attribute :utm_medium, :string, public?: true
    attribute :utm_campaign, :string, public?: true
    attribute :utm_content, :string, public?: true
    create_timestamp :inserted_at
  end
end
