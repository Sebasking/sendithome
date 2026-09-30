defmodule ShipperDirectory.Directory.DiscoveryRun do
  @moduledoc "One run of a discovery source (FMC import, Google lookups), with its counts."
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "discovery_runs"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read]

    create :start do
      accept [:source, :params]
      change set_attribute(:status, :running)
    end

    update :finish do
      accept [:stats]
      change set_attribute(:status, :succeeded)
      change set_attribute(:finished_at, &DateTime.utc_now/0)
    end

    update :fail do
      accept [:error]
      change set_attribute(:status, :failed)
      change set_attribute(:finished_at, &DateTime.utc_now/0)
    end

    read :recent do
      prepare build(sort: [inserted_at: :desc], limit: 5)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :source, :string, allow_nil?: false, public?: true
    attribute :params, :map, allow_nil?: false, default: %{}, public?: true

    attribute :status, :atom,
      allow_nil?: false,
      default: :running,
      constraints: [one_of: [:running, :succeeded, :failed]],
      public?: true

    attribute :stats, :map, allow_nil?: false, default: %{}, public?: true
    attribute :error, :string, public?: true
    attribute :finished_at, :utc_datetime_usec, public?: true
    timestamps()
  end
end
