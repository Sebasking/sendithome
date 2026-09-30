defmodule ShipperDirectory.Directory.PresenceCheck do
  @moduledoc "One run of the presence checker against a company. Append-only."
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "presence_checks"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :company_id,
        :checked_at,
        :url,
        :http_status,
        :final_url,
        :is_parked,
        :is_placeholder,
        :has_contact_info,
        :has_ssl,
        :matches_company,
        :verdict,
        :reason
      ]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :checked_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :url, :string, public?: true
    attribute :http_status, :integer, public?: true
    attribute :final_url, :string, public?: true
    attribute :is_parked, :boolean, allow_nil?: false, default: false, public?: true
    attribute :is_placeholder, :boolean, allow_nil?: false, default: false, public?: true
    attribute :has_contact_info, :boolean, allow_nil?: false, default: false, public?: true
    attribute :has_ssl, :boolean, allow_nil?: false, default: false, public?: true
    # True when the page shows the company's name or phone, or the domain contains its name.
    attribute :matches_company, :boolean, allow_nil?: false, default: false, public?: true

    attribute :verdict, ShipperDirectory.Directory.Types.PresenceStatus,
      allow_nil?: false,
      public?: true

    attribute :reason, :string, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company do
      allow_nil? false
    end
  end
end
