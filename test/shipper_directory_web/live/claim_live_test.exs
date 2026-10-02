defmodule ShipperDirectoryWeb.ClaimLiveTest do
  use ShipperDirectoryWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias ShipperDirectory.Directory

  setup do
    company =
      Directory.create_company!(%{
        name: "FCS Shipping LLC",
        website_url: "https://fcsshipping.com",
        phone: "(718) 483-8006",
        status: :published
      })

    %{company: company}
  end

  test "company page invites the owner to claim", %{conn: conn} do
    html = conn |> get(~p"/shippers/fcs-shipping-llc") |> html_response(200)
    assert html =~ "Claim this listing"
    refute html =~ "Verified owner"
  end

  test "claim by email end to end", %{conn: conn, company: company} do
    {:ok, view, html} = live(conn, ~p"/shippers/fcs-shipping-llc/claim")
    assert html =~ "Email me a code at @fcsshipping.com"
    assert html =~ "(•••) •••-8006"

    view
    |> form("#claim-form", %{method: "email", name: "Pat", email: "pat@fcsshipping.com"})
    |> render_submit()

    assert render(view) =~ "We emailed a 6-digit code to pat@fcsshipping.com"
    assert_received {:email, %{subject: subject}}
    [code] = Regex.run(~r/^\d{6}/, subject)

    view |> form("#code-form", %{code: "999999x"}) |> render_submit()
    assert render(view) =~ "That code isn&#39;t right"

    view |> form("#code-form", %{code: code}) |> render_submit()
    assert render(view) =~ "You&#39;re verified"
    assert_email_sent(to: "pat@fcsshipping.com")

    assert Directory.get_company!(company.id).owner_id
    html = build_conn() |> get(~p"/shippers/fcs-shipping-llc") |> html_response(200)
    assert html =~ "Verified owner"
    refute html =~ "Claim this listing"
  end

  test "webmail is refused for the email method", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/shippers/fcs-shipping-llc/claim")

    html =
      view
      |> form("#claim-form", %{method: "email", name: "Pat", email: "pat@gmail.com"})
      |> render_submit()

    assert html =~ "Use an email address at your website"
  end

  test "prospects can't be claimed publicly", %{conn: conn} do
    Directory.create_company!(%{name: "Barrel-It", status: :prospect})
    assert_error_sent 404, fn -> get(conn, ~p"/shippers/barrel-it/claim") end
  end
end
