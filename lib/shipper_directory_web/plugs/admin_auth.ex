defmodule ShipperDirectoryWeb.Plugs.AdminAuth do
  @moduledoc """
  HTTP basic auth for /admin. Placeholder until there are real accounts.
  Credentials come from `config :shipper_directory, :admin_auth`
  (ADMIN_USERNAME / ADMIN_PASSWORD in prod).
  """
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn, Application.fetch_env!(:shipper_directory, :admin_auth))
  end
end
