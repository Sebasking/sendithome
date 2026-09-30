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
      define :companies_due_for_check, action: :due_for_check, args: [:checked_before]
      define :record_presence, action: :record_presence
      define :approve_listing, action: :approve_listing
      define :reject_listing, action: :reject_listing
      define :set_company_status, action: :set_status, args: [:status]
      define :set_website, action: :set_website, args: [:website_url]
      define :record_google, action: :record_google
      define :confirm_caribbean, action: :confirm_caribbean
      define :exclude_company, action: :exclude
      define :dismiss_duplicate, action: :dismiss_duplicate
      define :triage_queue, action: :triage_queue
      define :duplicate_queue, action: :duplicate_queue
      define :companies_needing_google_lookup, action: :needs_google_lookup
      define :companies_by_name_core, action: :by_name_core, args: [:name_core]
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
    end
  end
end
