defmodule ShipperDirectory.Accounts do
  @moduledoc "Domain for listing-owner accounts."
  use Ash.Domain,
    otp_app: :shipper_directory

  resources do
    resource ShipperDirectory.Accounts.Token
    resource ShipperDirectory.Accounts.User
  end
end
