defmodule ShipperDirectoryWeb.AuthController do
  use ShipperDirectoryWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    # Owners land on their listings after signing in.
    return_to = get_session(conn, :return_to) || ~p"/my/listings"

    message = "You are now signed in"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, _reason) do
    message =
      case activity do
        {:magic_link, _} -> "That sign-in link is invalid or has expired. Request a new one."
        _ -> "Sign-in failed"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:shipper_directory)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end
