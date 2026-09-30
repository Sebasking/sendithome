defmodule ShipperDirectory.Directory.Types.OutreachChannel do
  @moduledoc """
  How we reached out. SMS and WhatsApp need prior consent (TCPA), so cold
  outreach uses calls, email, and in-person visits.
  """
  use Ash.Type.Enum, values: [:call, :sms, :whatsapp, :email, :in_person]
end
