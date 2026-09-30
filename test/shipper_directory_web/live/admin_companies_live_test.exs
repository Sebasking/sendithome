defmodule ShipperDirectoryWeb.Admin.CompaniesLiveTest do
  use ShipperDirectoryWeb.ConnCase

  use Oban.Testing, repo: ShipperDirectory.Repo

  import Phoenix.LiveViewTest

  alias ShipperDirectory.Directory

  defp authed(conn),
    do: put_req_header(conn, "authorization", Plug.BasicAuth.encode_basic_auth("admin", "secret"))

  test "requires basic auth", %{conn: conn} do
    assert conn |> get(~p"/admin") |> response(401)
  end

  test "review queue approve publishes the company", %{conn: conn} do
    company =
      Directory.create_company!(%{
        name: "Quality One International",
        website_url: "https://qualityone.example",
        presence_status: :needs_review,
        hold_for_review: true,
        review_reason: "Domain looks mismatched"
      })

    {:ok, view, html} = live(authed(conn), ~p"/admin?view=review")
    assert html =~ "Domain looks mismatched"

    view |> element("#company-#{company.id} button", "Approve") |> render_click()

    assert %{status: :published, presence_status: :listed, hold_for_review: false} =
             Directory.get_company!(company.id)
  end

  test "prospect status can be changed and exported", %{conn: conn} do
    company =
      Directory.create_company!(%{name: "Barrel-It", status: :prospect, phone: "718-555-0100"})

    Directory.create_company!(%{name: "Suppressed", status: :do_not_contact})

    {:ok, view, _html} = live(authed(conn), ~p"/admin?view=prospects")

    view
    |> element("#company-#{company.id} form")
    |> render_change(%{"company_id" => company.id, "status" => "contacted"})

    assert Directory.get_company!(company.id).status == :contacted

    csv = build_conn() |> authed() |> get(~p"/admin/prospects.csv") |> response(200)
    assert csv =~ "Barrel-It"
    refute csv =~ "Suppressed"
  end

  test "triage: confirm queues a Google lookup, exclude hides it", %{conn: conn} do
    a = Directory.create_company!(%{name: "Dennis Shipping", needs_triage: true})
    b = Directory.create_company!(%{name: "JFK Air Cargo", needs_triage: true})

    {:ok, view, _html} = live(authed(conn), ~p"/admin?view=triage")
    view |> element("#company-#{a.id} button", "Caribbean shipper") |> render_click()
    view |> element("#company-#{b.id} button", "Not Caribbean") |> render_click()

    assert %{needs_triage: false} = Directory.get_company!(a.id)
    assert %{status: :excluded} = Directory.get_company!(b.id)
    assert_enqueued worker: ShipperDirectory.Workers.GoogleLookupWorker, args: %{company_id: a.id}
    refute render(view) =~ "JFK Air Cargo"
  end

  test "duplicates: merge", %{conn: conn} do
    keep = Directory.create_company!(%{name: "Dennis Shipping"})

    dup =
      Directory.create_company!(%{
        name: "Dennis Shipping Co., Inc.",
        phone: "718-451-3617",
        possible_duplicate_of_id: keep.id
      })

    {:ok, view, html} = live(authed(conn), ~p"/admin?view=duplicates")
    assert html =~ "Possible duplicate of"

    view |> element("#company-#{dup.id} button", "Merge") |> render_click()
    assert %{phone: "718-451-3617"} = Directory.get_company!(keep.id)
  end

  test "review: entering a website saves it and runs the presence check", %{conn: conn} do
    Req.Test.stub(ShipperDirectory.Directory.Presence, fn conn ->
      Plug.Conn.send_resp(conn, 404, "nope")
    end)

    c =
      Directory.create_company!(%{
        name: "Barrel-It",
        presence_status: :needs_review,
        review_reason: "Google Maps lists a website"
      })

    {:ok, view, _html} = live(authed(conn), ~p"/admin?view=review")
    Req.Test.allow(ShipperDirectory.Directory.Presence, self(), view.pid)

    view
    |> form("#website-#{c.id}", %{"website_url" => "https://barrelit.example"})
    |> render_submit()

    assert Directory.get_company!(c.id).website_url == "https://barrelit.example"
  end
end
