defmodule ShipperDirectory.Directory.LeadDelivery do
  @moduledoc """
  One quote request sent to one shipper: the billable unit for pay-per-lead.
  `price_cents` is fixed when the lead is sent. A dispute the admin accepts
  marks it `credited` and it drops out of the invoice ledger.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  alias ShipperDirectory.Directory.Types.LeadDeliveryStatus

  postgres do
    table "lead_deliveries"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:lead_id, :company_id, :price_cents, :sent_to]
    end

    update :owner_update do
      description "What the shipper can set: their progress, or a dispute with a reason."
      accept [:status, :dispute_reason]
      validate attribute_in(:status, [:new, :contacted, :booked, :lost, :disputed])
    end

    update :resolve_dispute do
      require_atomic? false
      argument :accept?, :boolean, allow_nil?: false

      change fn changeset, _context ->
        status = if Ash.Changeset.get_argument(changeset, :accept?), do: :credited, else: :lost
        Ash.Changeset.force_change_attribute(changeset, :status, status)
      end
    end

    read :for_owner do
      argument :owner_id, :uuid, allow_nil?: false
      filter expr(company.owner_id == ^arg(:owner_id))
      prepare build(sort: [inserted_at: :desc], load: [:lead, :company])
    end

    read :disputed do
      filter expr(status == :disputed)
      prepare build(sort: [inserted_at: :asc], load: [:lead, :company])
    end

    read :billable_between do
      argument :from, :utc_datetime_usec, allow_nil?: false
      argument :to, :utc_datetime_usec, allow_nil?: false

      filter expr(
               inserted_at >= ^arg(:from) and inserted_at < ^arg(:to) and status != :credited and
                 price_cents > 0
             )

      prepare build(load: [:company])
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :price_cents, :integer, allow_nil?: false, default: 0, public?: true
    attribute :sent_to, :string, allow_nil?: false, public?: true

    attribute :status, LeadDeliveryStatus,
      allow_nil?: false,
      default: :new,
      public?: true

    attribute :dispute_reason, :string, public?: true
    timestamps()
  end

  relationships do
    belongs_to :lead, ShipperDirectory.Directory.Lead, allow_nil?: false
    belongs_to :company, ShipperDirectory.Directory.Company, allow_nil?: false
  end

  identities do
    identity :unique_lead_company, [:lead_id, :company_id]
  end
end
