defmodule ShipperDirectory.Directory.Company do
  @moduledoc """
  A Caribbean barrel/freight shipper. The presence check decides where it
  goes. A company with its own working website is published to the
  directory. One without a website (none, social-only, or a dead site)
  becomes a prospect.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Directory,
    data_layer: AshPostgres.DataLayer

  alias ShipperDirectory.Directory.Changes.{SetMatchKeys, SetSearchKeys}
  alias ShipperDirectory.Directory.Types.{CompanyStatus, PresenceStatus, Service}

  @contact_fields [
    :name,
    :phone,
    :email,
    :address,
    :city,
    :state,
    :lat,
    :lng,
    :website_url,
    :facebook_url,
    :instagram_url,
    :yelp_url,
    :google_place_id,
    :fmc_license_no,
    :services,
    :origin_metros,
    :destinations,
    :source,
    :notes,
    :sailing_schedule,
    :neighborhood,
    :whatsapp_number,
    :next_sailing_date,
    :christmas_cutoff_date,
    :pickup_available
  ]

  postgres do
    table "companies"
    repo ShipperDirectory.Repo

    references do
      reference :possible_duplicate_of, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept @contact_fields ++
               [
                 :slug,
                 :status,
                 :presence_status,
                 :review_reason,
                 :hold_for_review,
                 :needs_triage,
                 :possible_duplicate_of_id
               ]

      change SetMatchKeys
      change SetSearchKeys
    end

    update :update do
      require_atomic? false
      accept @contact_fields
      change SetMatchKeys
      change SetSearchKeys
    end

    update :record_presence do
      accept [:presence_status, :status, :review_reason, :last_checked_at]
    end

    update :approve_listing do
      description "Admin confirms the website belongs to this company and publishes it."
      change set_attribute(:presence_status, :listed)
      change set_attribute(:status, :published)
      change set_attribute(:review_reason, nil)
      change set_attribute(:hold_for_review, false)
    end

    update :reject_listing do
      description "Admin decides the website isn't really theirs, which makes the company a prospect."
      change set_attribute(:presence_status, :dead_site)
      change set_attribute(:status, :prospect)
      change set_attribute(:review_reason, nil)
      change set_attribute(:hold_for_review, false)
    end

    update :set_status do
      accept [:status]
    end

    update :set_verified do
      description "Admin confirms (or withdraws) a shipper by phone. Only verified shippers appear in the QR flow."
      require_atomic? false
      argument :verified, :boolean, allow_nil?: false

      change fn changeset, _context ->
        at = if Ash.Changeset.get_argument(changeset, :verified), do: DateTime.utc_now()
        Ash.Changeset.force_change_attribute(changeset, :verified_at, at)
      end
    end

    update :record_outreach_result do
      accept [:status, :messaging_consent_at, :messaging_consent_note]
    end

    update :owner_update do
      description "What a verified owner may change on their own listing."
      require_atomic? false

      accept [
        :phone,
        :email,
        :website_url,
        :address,
        :city,
        :state,
        :services,
        :origin_metros,
        :destinations,
        :sailing_schedule
      ]

      change SetMatchKeys
      change SetSearchKeys
    end

    update :assign_owner do
      accept [:owner_id]
      change set_attribute(:claimed_at, &DateTime.utc_now/0)
    end

    update :set_accepts_leads do
      description "The owner opts in (or out) of pay-per-lead quote requests."
      require_atomic? false
      accept [:accepts_leads]

      change fn changeset, _context ->
        at = if Ash.Changeset.get_attribute(changeset, :accepts_leads), do: DateTime.utc_now()
        Ash.Changeset.force_change_attribute(changeset, :leads_terms_accepted_at, at)
      end
    end

    read :lead_eligible do
      description "Published, claimed, and opted in to quote requests."
      argument :metro, :string
      argument :destination, :string

      filter expr(status == :published and not is_nil(owner_id) and accepts_leads)

      filter expr(is_nil(^arg(:metro)) or fragment("? = ANY(?)", ^arg(:metro), metro_slugs))

      filter expr(
               is_nil(^arg(:destination)) or
                 fragment("? = ANY(?)", ^arg(:destination), destination_slugs)
             )

      prepare build(sort: [:name])
    end

    update :remove_owner do
      change set_attribute(:owner_id, nil)
      change set_attribute(:claimed_at, nil)
      change set_attribute(:accepts_leads, false)
    end

    read :owned_by do
      argument :owner_id, :uuid, allow_nil?: false
      filter expr(owner_id == ^arg(:owner_id))
      prepare build(sort: [:name])
    end

    update :set_website do
      description "Admin enters the website by hand (e.g. after looking the company up on Google Maps)."
      accept [:website_url]
      change set_attribute(:hold_for_review, false)
    end

    update :record_google do
      accept [
        :google_place_id,
        :google_has_website,
        :google_checked_at,
        :presence_status,
        :status,
        :review_reason
      ]
    end

    update :confirm_caribbean do
      change set_attribute(:needs_triage, false)
    end

    update :exclude do
      description "Not a Caribbean shipper. Kept (with its sightings) so discovery won't recreate it."
      change set_attribute(:needs_triage, false)
      change set_attribute(:status, :excluded)
      change set_attribute(:possible_duplicate_of_id, nil)
    end

    update :dismiss_duplicate do
      change set_attribute(:possible_duplicate_of_id, nil)
    end

    read :find_match do
      description "Existing company with the same normalized phone or name + address."
      argument :normalized_phone, :string
      argument :name_key, :string, allow_nil?: false

      filter expr(
               (not is_nil(^arg(:normalized_phone)) and
                  normalized_phone == ^arg(:normalized_phone)) or
                 name_key == ^arg(:name_key)
             )
    end

    read :review_queue do
      filter expr(presence_status == :needs_review and status != :excluded)
      prepare build(sort: [:name])
    end

    read :triage_queue do
      filter expr(needs_triage and status != :excluded)
      prepare build(sort: [:state, :city, :name])
    end

    read :duplicate_queue do
      filter expr(not is_nil(possible_duplicate_of_id))
      prepare build(sort: [:name], load: [:possible_duplicate_of])
    end

    read :needs_google_lookup do
      description "Confirmed Caribbean shippers with no website, not yet looked up on Google."

      filter expr(
               not needs_triage and is_nil(google_checked_at) and is_nil(website_url) and
                 status not in [:excluded, :do_not_contact, :declined]
             )
    end

    read :by_name_core do
      argument :name_core, :string, allow_nil?: false
      filter expr(name_core == ^arg(:name_core))
    end

    read :published do
      filter expr(status == :published)
      prepare build(sort: [:name])
    end

    read :search do
      description "Public directory search. Only published companies, ever."
      argument :metro, :string
      argument :destination, :string
      argument :service, :string

      filter expr(status == :published)

      filter expr(is_nil(^arg(:metro)) or fragment("? = ANY(?)", ^arg(:metro), metro_slugs))

      filter expr(
               is_nil(^arg(:destination)) or
                 fragment("? = ANY(?)", ^arg(:destination), destination_slugs)
             )

      filter expr(is_nil(^arg(:service)) or fragment("? = ANY(?)", ^arg(:service), services))

      prepare build(sort: [:name])
    end

    read :directory_search do
      description "QR flow results: published, phone-verified shippers. Filters are optional."
      argument :destination_code, :string
      argument :area_slug, :string
      argument :when, :atom, default: :any, constraints: [one_of: [:any, :christmas]]
      argument :on, :date, default: &Date.utc_today/0

      filter expr(status == :published and not is_nil(verified_at))
      prepare ShipperDirectory.Directory.Preparations.DirectorySearch
      prepare build(sort: [:name])
    end

    read :prospects do
      filter expr(status in [:prospect, :contacted])
      prepare build(sort: [:name])
    end

    read :follow_ups_due do
      argument :before, :utc_datetime_usec, allow_nil?: false
      filter expr(status in [:prospect, :contacted] and next_action_at <= ^arg(:before))
      prepare build(sort: [:next_action_at], load: [:next_action_at, :last_outcome])
    end

    read :due_for_check do
      argument :checked_before, :utc_datetime_usec, allow_nil?: false

      filter expr(
               status not in [:do_not_contact, :excluded] and not needs_triage and
                 (is_nil(last_checked_at) or last_checked_at < ^arg(:checked_before))
             )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    attribute :phone, :string, public?: true
    attribute :email, :string, public?: true
    attribute :address, :string, public?: true
    attribute :city, :string, public?: true
    attribute :state, :string, public?: true
    attribute :lat, :float, public?: true
    attribute :lng, :float, public?: true

    attribute :website_url, :string, public?: true
    attribute :facebook_url, :string, public?: true
    attribute :instagram_url, :string, public?: true
    attribute :yelp_url, :string, public?: true
    attribute :google_place_id, :string, public?: true
    attribute :fmc_license_no, :string, public?: true

    attribute :presence_status, PresenceStatus, public?: true

    attribute :status, CompanyStatus,
      allow_nil?: false,
      default: :discovered,
      public?: true

    # Why the company is in the review queue.
    attribute :review_reason, :string, public?: true

    # Set when a person flagged this company. The presence checker then
    # records its verdict but won't publish or demote. An admin decides.
    attribute :hold_for_review, :boolean, allow_nil?: false, default: false, public?: true

    # FMC licensees without a Caribbean keyword in their name wait here
    # until a person confirms they're a Caribbean shipper.
    attribute :needs_triage, :boolean, allow_nil?: false, default: false, public?: true

    # Google Places terms allow storing only the place ID indefinitely, so
    # we keep the ID plus our own derived flag, never Google's content.
    attribute :google_has_website, :boolean, public?: true
    attribute :google_checked_at, :utc_datetime_usec, public?: true

    attribute :services, {:array, Service}, allow_nil?: false, default: [], public?: true
    attribute :origin_metros, {:array, :string}, allow_nil?: false, default: [], public?: true
    attribute :destinations, {:array, :string}, allow_nil?: false, default: [], public?: true
    attribute :source, {:array, :string}, allow_nil?: false, default: [], public?: true
    attribute :sailing_schedule, :string, public?: true

    # Shown on QR flow result cards.
    attribute :neighborhood, :string, public?: true
    attribute :whatsapp_number, :string, public?: true
    attribute :next_sailing_date, :date, public?: true
    # Last drop-off date for Christmas delivery. Nil means unknown, never "any time".
    attribute :christmas_cutoff_date, :date, public?: true
    attribute :pickup_available, :boolean, public?: true

    # Set when we've confirmed the shipper by phone. Only verified shippers
    # appear in the QR flow.
    attribute :verified_at, :utc_datetime_usec, public?: true

    # Canonical slugs derived by SetSearchKeys, for search and route pages.
    attribute :metro_slugs, {:array, :string}, allow_nil?: false, default: [], public?: true
    attribute :destination_slugs, {:array, :string}, allow_nil?: false, default: [], public?: true

    attribute :claimed_at, :utc_datetime_usec, public?: true

    # Pay-per-lead is opt-in: only owners who accepted the terms get leads.
    attribute :accepts_leads, :boolean, allow_nil?: false, default: false, public?: true
    attribute :leads_terms_accepted_at, :utc_datetime_usec, public?: true

    # TCPA: SMS/WhatsApp outreach only after the company opts in.
    attribute :messaging_consent_at, :utc_datetime_usec, public?: true
    attribute :messaging_consent_note, :string, public?: true

    attribute :last_checked_at, :utc_datetime_usec, public?: true
    attribute :notes, :string, public?: true

    # Match keys, maintained by SetMatchKeys.
    attribute :normalized_phone, :string
    attribute :name_key, :string, allow_nil?: false
    # Sorted distinctive name words, used to flag possible duplicates.
    attribute :name_core, :string
    attribute :dedupe_key, :string, allow_nil?: false

    timestamps()
  end

  relationships do
    belongs_to :possible_duplicate_of, __MODULE__, public?: true
    belongs_to :owner, ShipperDirectory.Accounts.User, public?: true
    has_many :claims, ShipperDirectory.Directory.Claim
    has_many :lead_deliveries, ShipperDirectory.Directory.LeadDelivery
    has_many :placements, ShipperDirectory.Directory.Placement

    has_many :sightings, ShipperDirectory.Directory.Sighting
    has_many :presence_checks, ShipperDirectory.Directory.PresenceCheck
    has_many :outreach_events, ShipperDirectory.Directory.OutreachEvent
  end

  aggregates do
    max :last_outreach_at, :outreach_events, :inserted_at
    count :outreach_count, :outreach_events

    first :last_outcome, :outreach_events, :outcome do
      sort inserted_at: :desc
    end

    # The follow-up date set on the most recent touch.
    first :next_action_at, :outreach_events, :next_action_at do
      sort inserted_at: :desc
      include_nil? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
    identity :unique_dedupe_key, [:dedupe_key]
  end
end
