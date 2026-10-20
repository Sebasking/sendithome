defmodule ShipperDirectoryWeb.AuthPagesTest do
  use ShipperDirectoryWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ShipperDirectoryWeb.Brand

  test "sign-in page is branded with the active logo", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    assert has_element?(view, "#auth-logo img[src='#{Brand.asset("lockup.svg")}']")
    assert has_element?(view, "#auth-heading", "Shipper sign in")
    assert has_element?(view, "#auth-card input[type=email]")
    refute has_element?(view, "img[src*='ash-hq.org']")
  end

  test "magic link landing page is branded", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/magic_link/some-token")

    assert has_element?(view, "#auth-logo img[src='#{Brand.asset("lockup.svg")}']")
    assert has_element?(view, "#auth-heading", "Finish signing in")
    assert has_element?(view, "#auth-card button[type=submit]")
    refute has_element?(view, "img[src*='ash-hq.org']")
  end
end
