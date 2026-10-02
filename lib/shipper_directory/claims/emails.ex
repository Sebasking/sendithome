defmodule ShipperDirectory.Claims.Emails do
  @moduledoc "Transactional emails for the claim flow."
  import Swoosh.Email

  def from,
    do:
      Application.get_env(
        :shipper_directory,
        :mail_from,
        {"Caribbean Shipper Directory", "noreply@example.com"}
      )

  def claim_code(to, code, company) do
    new()
    |> from(from())
    |> to(to)
    |> subject("#{code} is your code to claim #{company.name}")
    |> text_body("""
    Someone (hopefully you) asked to claim the #{company.name} listing on Caribbean Shipper Directory.

    Your verification code is: #{code}

    It expires in 15 minutes. If you didn't ask for this, you can ignore this email.
    """)
  end
end
