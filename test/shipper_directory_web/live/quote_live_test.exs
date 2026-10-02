defmodule ShipperDirectoryWeb.QuoteLiveTest do
  use ShipperDirectoryWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ShipperDirectory.Fixtures
  import Swoosh.TestAssertions

  alias ShipperDirectory.Directory

  test "route request: pick shippers, consent names them, sends", %{conn: conn} do
    a = company(%{name: "Alpha Shipping", owner: "alpha@example.com"})
    b = company(%{name: "Beta Cargo", owner: "beta@example.com"})
    _not_opted_in = company(%{name: "Gamma"})

    {:ok, view, html} = live(conn, ~p"/quote?from=brooklyn&to=guyana")
    assert html =~ "Alpha Shipping"
    assert html =~ "Beta Cargo"
    refute html =~ "Gamma"

    html =
      view
      |> form("#quote-form", %{"companies" => ["", a.id]})
      |> render_change()

    assert html =~ "By sending this request, I agree that Alpha Shipping may contact me"

    view
    |> form("#quote-form", %{
      "companies" => ["", a.id],
      "lead" => %{"name" => "Marcia", "phone" => "347-555-0101", "barrels" => "2"}
    })
    |> render_submit()

    assert render(view) =~ "Request sent"
    assert_email_sent(to: "alpha@example.com")

    [lead] = Directory.recent_leads!()
    assert [%{company_id: id}] = lead.deliveries
    assert id == a.id
    refute Enum.any?(lead.deliveries, &(&1.company_id == b.id))
  end

  test "company request goes to that company only", %{conn: conn} do
    a = company(%{name: "Alpha Shipping", owner: "alpha@example.com"})

    {:ok, view, html} = live(conn, ~p"/quote?company=#{a.slug}")
    assert html =~ "Get a quote from Alpha Shipping"

    view
    |> form("#quote-form", %{"lead" => %{"name" => "Marcia", "email" => "m@example.com"}})
    |> render_submit()

    assert render(view) =~ "Request sent"
    assert_email_sent(to: "alpha@example.com")
  end

  test "no eligible shippers", %{conn: conn} do
    company(%{name: "Unclaimed"})
    {:ok, _view, html} = live(conn, ~p"/quote?from=brooklyn&to=guyana")
    assert html =~ "No shippers on this route take online requests yet"
  end

  test "route and company pages link to quotes only when someone can receive them", %{conn: conn} do
    plain = company(%{name: "Plain"})

    refute conn |> get(~p"/ship-barrel/brooklyn-to-guyana") |> html_response(200) =~
             "Get free quotes"

    refute build_conn() |> get(~p"/shippers/#{plain.slug}") |> html_response(200) =~ "Get a quote"

    owned = company(%{name: "Owned", owner: "o@example.com"})

    assert build_conn() |> get(~p"/ship-barrel/brooklyn-to-guyana") |> html_response(200) =~
             "Get free quotes"

    assert build_conn() |> get(~p"/shippers/#{owned.slug}") |> html_response(200) =~ "Get a quote"
  end

  test "sponsored companies show first, labeled, on routes and search", %{conn: conn} do
    company(%{name: "Organic Co"})
    sponsor = company(%{name: "Sponsor Co"})
    today = Date.utc_today()

    Directory.create_placement!(%{
      company_id: sponsor.id,
      metro: "brooklyn",
      destination: "guyana",
      starts_on: today,
      ends_on: Date.add(today, 7)
    })

    html = conn |> get(~p"/ship-barrel/brooklyn-to-guyana") |> html_response(200)
    [sponsored_section] = Regex.run(~r/<section[^>]*id="sponsored".*?<\/section>/s, html)
    assert sponsored_section =~ "Sponsor Co"
    refute sponsored_section =~ "Organic Co"
    # Shown once (in the sponsored block), not repeated in the organic list.
    assert length(String.split(html, ~s(href="/shippers/#{sponsor.slug}"))) == 2

    {:ok, _view, html} = live(build_conn(), ~p"/?from=brooklyn")
    assert html =~ ~s(id="sponsored")
    {:ok, _view, html} = live(build_conn(), ~p"/")
    refute html =~ ~s(id="sponsored")
  end
end
