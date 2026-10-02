defmodule ShipperDirectory.Secrets do
  @moduledoc "Provides the token signing secret to AshAuthentication."
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        ShipperDirectory.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:shipper_directory, :token_signing_secret)
  end
end
