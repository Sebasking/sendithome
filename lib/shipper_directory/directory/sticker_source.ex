defmodule ShipperDirectory.Directory.StickerSource do
  @moduledoc """
  A batch of QR stickers placed in one store. The sticker URL carries the
  code (`/s/store-123`), which tells the flow which area to prefer and
  which logo design the batch carries (for the logo A/B test).
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  alias ShipperDirectory.Directory.Types.Metro

  postgres do
    table "sticker_sources"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :active do
      filter expr(active)
    end
  end

  validations do
    validate match(:code, ~r/^[a-z0-9][a-z0-9-]*$/),
      message: "may only contain lowercase letters, digits and dashes"
  end

  attributes do
    uuid_primary_key :id
    attribute :code, :string, allow_nil?: false, public?: true
    # e.g. "Jamaica Ave Discount, batch 1"
    attribute :label, :string, allow_nil?: false, public?: true
    attribute :store_name, :string, public?: true
    attribute :distributor_name, :string, public?: true
    # Nil = no area preference.
    attribute :area, Metro, public?: true

    attribute :logo_variant, :atom,
      constraints: [one_of: [:a, :b]],
      public?: true

    attribute :active, :boolean, allow_nil?: false, default: true, public?: true
    timestamps()
  end

  identities do
    identity :unique_code, [:code]
  end
end
