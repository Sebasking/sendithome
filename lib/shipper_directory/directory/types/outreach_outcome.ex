defmodule ShipperDirectory.Directory.Types.OutreachOutcome do
  @moduledoc """
  Result of one outreach touchpoint. Some outcomes move the company's
  status (see `Changes.ApplyOutreachOutcome`).
  """
  use Ash.Type.Enum,
    values: [
      no_answer: "No answer",
      left_message: "Left a message",
      interested: "Interested",
      not_interested: "Not interested",
      meeting_booked: "Meeting booked",
      customer: "Became a customer",
      opted_in_messaging: "Opted in to SMS/WhatsApp",
      do_not_contact: "Asked not to be contacted",
      other: "Other"
    ]
end
