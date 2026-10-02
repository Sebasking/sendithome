defmodule ShipperDirectory.Leads.Emails do
  @moduledoc "Lead notifications for shippers and confirmations for consumers."
  use ShipperDirectoryWeb, :verified_routes

  import Swoosh.Email

  alias ShipperDirectory.Claims.Emails, as: ClaimEmails
  alias ShipperDirectory.Leads

  def new_lead(delivery, lead, company) do
    new()
    |> from(ClaimEmails.from())
    |> to(delivery.sent_to)
    |> subject("New quote request: #{Leads.route_label(lead)}")
    |> text_body("""
    #{company.name} has a new quote request from Caribbean Shipper Directory.

    From:     #{lead.name}
    Phone:    #{lead.phone || "-"}
    Email:    #{lead.email || "-"}
    Route:    #{Leads.route_label(lead)}
    Items:    #{blank(Leads.items_label(lead))}
    Pickup:   #{if lead.pickup_needed, do: "Yes, needs pickup", else: "Will drop off"}
    Ship by:  #{if lead.ship_by, do: Calendar.strftime(lead.ship_by, "%B %-d, %Y"), else: "Flexible"}
    Notes:    #{lead.notes || "-"}

    They asked to be contacted by you and at most #{Leads.max_companies() - 1} other shippers. Reply quickly!
    #{price_line(delivery)}
    Manage your requests: #{url(~p"/my/leads")}
    """)
  end

  def confirmation(lead, companies) do
    new()
    |> from(ClaimEmails.from())
    |> to(to_string(lead.email))
    |> subject("Your shipping request was sent")
    |> text_body("""
    Hi #{lead.name},

    Your request (#{Leads.route_label(lead)}) was sent to:
    #{Enum.map_join(companies, "\n", &"- #{&1.name}#{if &1.phone, do: " (#{&1.phone})"}")}

    They'll contact you directly with rates and pickup or drop-off details.
    """)
  end

  defp price_line(%{price_cents: 0}), do: ""

  defp price_line(%{price_cents: cents}),
    do:
      "\nThis request is billed at #{Leads.format_price(cents)}. Not a real customer? Dispute it from your dashboard.\n"

  defp blank(""), do: "-"
  defp blank(value), do: value
end
