defmodule ShipperDirectoryWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ShipperDirectoryWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias AshAuthentication.Plug.Helpers

  using do
    quote do
      # The default endpoint for testing
      @endpoint ShipperDirectoryWeb.Endpoint

      use ShipperDirectoryWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ShipperDirectoryWeb.ConnCase
    end
  end

  setup tags do
    ShipperDirectory.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Creates a listing owner (if given an email) and signs them in on the conn."
  def log_in_owner(conn, email) when is_binary(email) do
    user =
      ShipperDirectory.Accounts.User
      |> Ash.Changeset.for_create(:register_for_claim, %{email: email})
      |> Ash.create!(authorize?: false)

    {log_in_owner(conn, user), user}
  end

  def log_in_owner(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    user = Ash.Resource.put_metadata(user, :token, token)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Helpers.store_in_session(user)
  end
end
