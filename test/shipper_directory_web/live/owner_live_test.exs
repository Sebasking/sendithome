defmodule ShipperDirectoryWeb.OwnerLiveTest do
  use ShipperDirectoryWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ShipperDirectory.Directory

  setup %{conn: conn} do
    {conn, user} = log_in_owner(conn, "pat@fcsshipping.com")

    company =
      Directory.create_company!(%{
        name: "FCS Shipping LLC",
        website_url: "https://fcsshipping.com",
        status: :published
      })

    Directory.assign_owner!(company, user.id)
    other = Directory.create_company!(%{name: "Someone Else", status: :published})

    %{conn: conn, company: company, other: other}
  end

  test "my listings requires sign-in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/my/listings")
  end

  test "lists the owner's companies only", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/my/listings")
    assert html =~ "FCS Shipping LLC"
    refute html =~ "Someone Else"
  end

  test "owner edits their listing", %{conn: conn, company: company} do
    {:ok, view, html} = live(conn, ~p"/my/listings/fcs-shipping-llc")
    refute html =~ "Internal notes"
    refute html =~ ~s(name="company[name]")

    view
    |> form("#company-form",
      company: %{
        city: "Brooklyn",
        state: "NY",
        destinations: "Guyana",
        sailing_schedule: "Fridays"
      }
    )
    |> render_submit(%{"company" => %{"services" => ["", "barrel"]}})

    assert %{sailing_schedule: "Fridays", destination_slugs: ["guyana"], services: [:barrel]} =
             Directory.get_company!(company.id)
  end

  test "a new website is re-verified", %{conn: conn, company: company} do
    Req.Test.stub(ShipperDirectory.Directory.Presence, &Plug.Conn.send_resp(&1, 404, "gone"))
    {:ok, view, _html} = live(conn, ~p"/my/listings/fcs-shipping-llc")
    Req.Test.allow(ShipperDirectory.Directory.Presence, self(), view.pid)

    view
    |> form("#company-form", company: %{website_url: "https://broken.example"})
    |> render_submit()

    render_async(view)
    assert render(view) =~ "listing is hidden for now"

    assert %{status: :prospect, website_url: "https://broken.example"} =
             Directory.get_company!(company.id)
  end

  test "can't edit someone else's listing", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/my/listings"}}} =
             live(conn, ~p"/my/listings/someone-else")
  end
end
