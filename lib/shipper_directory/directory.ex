defmodule ShipperDirectory.Directory do
  @moduledoc """
  Domain for Caribbean shippers: the public directory (companies with a
  working website) and the private prospect pipeline (those without one).
  """
  use Ash.Domain, otp_app: :shipper_directory

  resources do
    resource ShipperDirectory.Directory.Company do
      define :create_company, action: :create
      define :update_company, action: :update
      define :get_company, action: :read, get_by: [:id]
      define :get_company_by_slug, action: :read, get_by: [:slug]
      define :list_companies, action: :read
      define :find_matching_companies, action: :find_match, args: [:normalized_phone, :name_key]
      define :review_queue, action: :review_queue
      define :published_companies, action: :published
      define :get_published_company, action: :published, get_by: [:slug]
      define :search_companies, action: :search
      define :prospects, action: :prospects
      define :follow_ups_due, action: :follow_ups_due, args: [:before]
      define :companies_due_for_check, action: :due_for_check, args: [:checked_before]
      define :record_presence, action: :record_presence
      define :approve_listing, action: :approve_listing
      define :reject_listing, action: :reject_listing
      define :set_company_status, action: :set_status, args: [:status]
      define :set_company_verified, action: :set_verified, args: [:verified]
      define :directory_search, action: :directory_search
      define :set_website, action: :set_website, args: [:website_url]
      define :record_outreach_result, action: :record_outreach_result
      define :owner_update_company, action: :owner_update
      define :assign_owner, action: :assign_owner, args: [:owner_id]
      define :remove_owner, action: :remove_owner
      define :set_accepts_leads, action: :set_accepts_leads, args: [:accepts_leads]
      define :lead_eligible_companies, action: :lead_eligible
      define :companies_owned_by, action: :owned_by, args: [:owner_id]
      define :record_google, action: :record_google
      define :confirm_caribbean, action: :confirm_caribbean
      define :exclude_company, action: :exclude
      define :dismiss_duplicate, action: :dismiss_duplicate
      define :triage_queue, action: :triage_queue
      define :duplicate_queue, action: :duplicate_queue
      define :companies_needing_google_lookup, action: :needs_google_lookup
      define :companies_by_name_core, action: :by_name_core, args: [:name_core]
    end

    resource ShipperDirectory.Directory.Destination do
      define :create_destination, action: :create
      define :active_destinations, action: :active

      define :get_active_destination,
        action: :active,
        get_by: [:code],
        not_found_error?: false
    end

    resource ShipperDirectory.Directory.StickerSource do
      define :create_sticker_source, action: :create

      define :get_active_sticker_source,
        action: :active,
        get_by: [:code],
        not_found_error?: false
    end

    resource ShipperDirectory.Directory.Sighting do
      define :record_sighting, action: :record
      define :get_sighting, action: :read, get_by: [:source, :external_id]
    end

    resource ShipperDirectory.Directory.PresenceCheck do
      define :create_presence_check, action: :create
    end

    resource ShipperDirectory.Directory.DiscoveryRun do
      define :start_discovery_run, action: :start, args: [:source]
      define :finish_discovery_run, action: :finish
      define :fail_discovery_run, action: :fail, args: [:error]
      define :recent_discovery_runs, action: :recent
    end

    resource ShipperDirectory.Directory.OutreachEvent do
      define :log_outreach, action: :create
      define :outreach_for_company, action: :for_company, args: [:company_id]
    end

    resource ShipperDirectory.Directory.Lead do
      define :create_lead, action: :create
      define :get_lead, action: :read, get_by: [:id]
      define :recent_leads, action: :recent
      define :recent_leads_from_contact, action: :recent_from_contact
    end

    resource ShipperDirectory.Directory.LeadDelivery do
      define :create_lead_delivery, action: :create
      define :get_lead_delivery, action: :read, get_by: [:id]
      define :owner_update_lead_delivery, action: :owner_update
      define :resolve_dispute, action: :resolve_dispute, args: [:accept?]
      define :lead_deliveries_for_owner, action: :for_owner, args: [:owner_id]
      define :disputed_lead_deliveries, action: :disputed
      define :billable_lead_deliveries, action: :billable_between, args: [:from, :to]
    end

    resource ShipperDirectory.Directory.Placement do
      define :create_placement, action: :create
      define :get_placement, action: :read, get_by: [:id]
      define :end_placement, action: :end_now
      define :active_placements, action: :active_for, args: [:metro, :destination, :on]
      define :list_placements, action: :listing
    end

    resource ShipperDirectory.Directory.Claim do
      define :create_claim, action: :create
      define :get_claim, action: :read, get_by: [:id]
      define :record_claim_attempt, action: :record_attempt
      define :mark_claim_verified, action: :mark_verified, args: [:user_id]
      define :recent_claims_for_company, action: :recent_for_company, args: [:company_id, :since]
      define :claims_for_company, action: :for_company, args: [:company_id]
    end
  end
end
