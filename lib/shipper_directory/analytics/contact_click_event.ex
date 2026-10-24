defmodule ShipperDirectory.Analytics.ContactClickEvent do
  @moduledoc "A visitor tapped Call, WhatsApp or Website on a QR flow result (via `/go`)."
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "contact_click_events"
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
      accept [:company_id, :channel, :sponsored, :destination_code, :source_code, :utm_content]
    end

    destroy :expire do
      description "Retention job only."
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :channel, :atom,
      allow_nil?: false,
      constraints: [one_of: [:call, :whatsapp, :website]],
      public?: true

    attribute :sponsored, :boolean, allow_nil?: false, default: false, public?: true
    attribute :destination_code, :string, public?: true
    attribute :source_code, :string, public?: true
    attribute :utm_content, :string, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company, public?: true
  end
end
