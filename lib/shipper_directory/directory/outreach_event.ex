defmodule ShipperDirectory.Directory.OutreachEvent do
  @moduledoc "A logged touchpoint with a prospect (call, email, visit, ...)."
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "outreach_events"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:company_id, :channel, :outcome, :notes, :next_action_at]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :channel, ShipperDirectory.Directory.Types.OutreachChannel,
      allow_nil?: false,
      public?: true

    attribute :outcome, :string, public?: true
    attribute :notes, :string, public?: true
    attribute :next_action_at, :utc_datetime, public?: true
    timestamps()
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company do
      allow_nil? false
    end
  end
end
