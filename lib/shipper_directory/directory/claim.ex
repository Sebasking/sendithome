defmodule ShipperDirectory.Directory.Claim do
  @moduledoc """
  An owner's attempt to claim a listing, verified by a 6-digit code sent
  to an email address at the company's domain or to the company's listed
  phone. Only a bcrypt hash of the code is stored. See `ShipperDirectory.Claims`.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "claims"
    repo ShipperDirectory.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :company_id,
        :method,
        :destination,
        :claimant_name,
        :claimant_email,
        :code_hash,
        :expires_at
      ]
    end

    update :record_attempt do
      accept [:attempts, :status]
    end

    update :mark_verified do
      accept [:user_id]
      change set_attribute(:status, :verified)
      change set_attribute(:verified_at, &DateTime.utc_now/0)
    end

    read :recent_for_company do
      argument :company_id, :uuid, allow_nil?: false
      argument :since, :utc_datetime_usec, allow_nil?: false
      filter expr(company_id == ^arg(:company_id) and inserted_at > ^arg(:since))
    end

    read :for_company do
      argument :company_id, :uuid, allow_nil?: false
      filter expr(company_id == ^arg(:company_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :method, :atom,
      allow_nil?: false,
      constraints: [one_of: [:email, :sms, :call]],
      public?: true

    # Where the code was sent: an email at the company's domain, or the
    # company's listed phone in E.164.
    attribute :destination, :string, allow_nil?: false, public?: true
    attribute :claimant_name, :string, allow_nil?: false, public?: true
    # Where the owner will sign in (magic link).
    attribute :claimant_email, :ci_string, allow_nil?: false, public?: true
    attribute :code_hash, :string, allow_nil?: false, sensitive?: true
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false
    attribute :attempts, :integer, allow_nil?: false, default: 0

    attribute :status, :atom,
      allow_nil?: false,
      default: :pending,
      constraints: [one_of: [:pending, :verified, :locked]],
      public?: true

    attribute :verified_at, :utc_datetime_usec, public?: true
    timestamps()
  end

  relationships do
    belongs_to :company, ShipperDirectory.Directory.Company, allow_nil?: false
    belongs_to :user, ShipperDirectory.Accounts.User
  end
end
