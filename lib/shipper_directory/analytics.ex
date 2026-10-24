defmodule ShipperDirectory.Analytics do
  @moduledoc """
  Server-side events for the QR flow: scans, answers, impressions and
  contact clicks. Append-only and free of personal data: no IPs, user
  agents, cookies or anything a visitor types. Rows older than
  `:event_retention_months` are deleted by `Workers.EventRetentionWorker`.
  Write them through `Analytics.EventLog`, never directly from a request.
  """
  use Ash.Domain, otp_app: :shipper_directory

  alias Ash.Domain.Info

  resources do
    resource ShipperDirectory.Analytics.ScanEvent
    resource ShipperDirectory.Analytics.FlowAnswerEvent
    resource ShipperDirectory.Analytics.ImpressionEvent
    resource ShipperDirectory.Analytics.ContactClickEvent
  end

  @doc "Every event resource, e.g. for the retention job."
  def event_resources, do: Info.resources(__MODULE__)
end
