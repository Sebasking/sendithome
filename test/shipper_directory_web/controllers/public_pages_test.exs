defmodule ShipperDirectoryWeb.PublicPagesTest do
  use ShipperDirectoryWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ShipperDirectory.Directory

  setup do
    listed =
      Directory.create_company!(%{
        name: "FCS Shipping LLC",
        city: "Brooklyn",
        state: "NY",
        phone: "(718) 483-8006",
        destinations: ["St. Lucia", "Guyana"],
        services: [:barrel],
        sailing_schedule: "Sails every Friday",
        fmc_license_no: "012345",
        website_url: "https://fcsshipping.com",
        status: :published
      })

    prospect =
      Directory.create_company!(%{
        name: "Barrel-It Caribbean Shipping",
        city: "Brooklyn",
        state: "NY",
        destinations: ["Haiti"],
        status: :prospect
      })

    %{listed: listed, prospect: prospect}
  end

  describe "company page" do
    test "shows a published company with JSON-LD", %{conn: conn} do
      html = conn |> get(~p"/shippers/fcs-shipping-llc") |> html_response(200)

      assert html =~ "FCS Shipping LLC"
      assert html =~ "Sails every Friday"
      assert html =~ "FMC licensed"
      assert html =~ ~s(href="/ship-barrel/brooklyn-to-guyana")
      assert html =~ ~s("@type":"LocalBusiness")
      assert html =~ ~s(rel="canonical" href="#{url(~p"/shippers/fcs-shipping-llc")}")
    end

    test "prospects have no public page", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/shippers/barrel-it-caribbean-shipping") end
    end
  end

  describe "route pages" do
    test "lists the companies serving the route", %{conn: conn} do
      html = conn |> get(~p"/ship-barrel/brooklyn-to-st-lucia") |> html_response(200)
      assert html =~ "Ship a barrel from Brooklyn to St. Lucia"
      assert html =~ "FCS Shipping LLC"
      assert html =~ "More from Brooklyn"
    end

    test "unknown routes and routes only prospects serve are 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/ship-barrel/brooklyn-to-atlantis") end
      assert_error_sent 404, fn -> get(conn, ~p"/ship-barrel/brooklyn-to-haiti") end
    end

    test "index groups routes by origin", %{conn: conn} do
      html = conn |> get(~p"/ship-barrel") |> html_response(200)
      assert html =~ "From Brooklyn"
      refute html =~ "Haiti"
    end
  end

  test "sitemap lists public pages only", %{conn: conn} do
    xml = conn |> get(~p"/sitemap.xml") |> response(200)
    assert xml =~ "/shippers/fcs-shipping-llc"
    assert xml =~ "/ship-barrel/brooklyn-to-guyana"
    refute xml =~ "barrel-it"
    refute xml =~ "haiti"
  end

  test "robots.txt blocks admin and points at the sitemap", %{conn: conn} do
    body = conn |> get(~p"/robots.txt") |> response(200)
    assert body =~ "Disallow: /admin"
    assert body =~ "Sitemap: #{url(~p"/sitemap.xml")}"
  end

  describe "home search" do
    test "filters from the URL and never shows prospects", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/?from=brooklyn&to=guyana")
      assert html =~ "FCS Shipping LLC"
      refute html =~ "Barrel-It"

      assert html =~
               ~s(rel="canonical" href="#{url(~p"/ship-barrel/brooklyn-to-guyana")}")
    end

    test "changing a filter patches the URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#search", search: %{from: "miami", to: "", service: ""})
      |> render_change()

      assert_patch(view, ~p"/?from=miami")
      assert render(view) =~ "No listed shippers match yet"
    end

    test "ignores unknown filter values", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/?from=atlantis")
      assert html =~ "FCS Shipping LLC"
    end
  end
end
