defmodule ShipperDirectory.Directory.Destination do
  @moduledoc """
  A destination offered on the first screen of the QR flow. `code` is the
  lowercase ISO 3166 alpha-2 code used in URLs (`/shippers?to=jm`); `slug`
  is the canonical `Destinations` slug that companies are tagged with, which
  is how a destination finds its shippers. Flags are rendered by code in
  `ShipperDirectoryWeb.FlowComponents.flag/1`.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  alias ShipperDirectory.Directory.Types.DestinationSlug

  postgres do
    table "destinations"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :active do
      filter expr(active)
      prepare build(sort: [:sort_order, :name])
    end
  end

  validations do
    validate match(:code, ~r/^[a-z]{2}$/),
      message: "must be a lowercase ISO 3166 alpha-2 code"
  end

  attributes do
    uuid_primary_key :id
    attribute :code, :string, allow_nil?: false, public?: true
    attribute :slug, DestinationSlug, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :sort_order, :integer, allow_nil?: false, default: 0, public?: true
    attribute :active, :boolean, allow_nil?: false, default: true, public?: true
    timestamps()
  end

  identities do
    identity :unique_code, [:code]
  end
end
