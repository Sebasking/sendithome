defmodule ShipperDirectoryWeb.Admin.ProspectsLiveTest do
  use ShipperDirectoryWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ShipperDirectory.Directory

  defp authed(conn),
    do: put_req_header(conn, "authorization", Plug.BasicAuth.encode_basic_auth("admin", "secret"))

  setup do
    brooklyn =
      Directory.create_company!(%{
        name: "Barrel-It",
        city: "Brooklyn",
        state: "NY",
        phone: "718-555-0100",
        status: :prospect
      })

    miami =
      Directory.create_company!(%{
        name: "Miami Cargo",
        city: "Miami",
        state: "FL",
        status: :prospect
      })

    Directory.create_company!(%{name: "Suppressed Co", status: :do_not_contact})

    %{brooklyn: brooklyn, miami: miami}
  end

  test "lists prospects by fit and hides the suppression list", %{conn: conn} do
    {:ok, _view, html} = live(authed(conn), ~p"/admin/prospects")
    assert html =~ "Barrel-It"
    assert html =~ "Miami Cargo"
    refute html =~ "Suppressed Co"
    [first, _] = Regex.scan(~r/id="prospect-([^"]+)"/, html) |> Enum.map(&List.last/1)
    assert first == Enum.find(Directory.prospects!(), &(&1.name == "Barrel-It")).id
  end

  test "metro filter", %{conn: conn} do
    {:ok, _view, html} = live(authed(conn), ~p"/admin/prospects?metro=miami")
    assert html =~ "Miami Cargo"
    refute html =~ "Barrel-It"
  end

  test "one-click log sets contacted and a follow-up", %{conn: conn, brooklyn: brooklyn} do
    {:ok, view, _html} = live(authed(conn), ~p"/admin/prospects")

    view
    |> element("#prospect-#{brooklyn.id} button", "No answer")
    |> render_click()

    c = Directory.get_company!(brooklyn.id, load: [:next_action_at, :last_outcome])
    assert %{status: :contacted, last_outcome: :no_answer} = c
    assert Date.diff(DateTime.to_date(c.next_action_at), Date.utc_today()) == 2
  end

  test "due filter shows overdue follow-ups", %{conn: conn, brooklyn: brooklyn} do
    Directory.log_outreach!(%{
      company_id: brooklyn.id,
      channel: :call,
      outcome: :left_message,
      next_action_at: DateTime.add(DateTime.utc_now(), -1, :day)
    })

    {:ok, _view, html} = live(authed(conn), ~p"/admin/prospects?due=1")
    assert html =~ "Barrel-It"
    refute html =~ "Miami Cargo"
  end

  test "panel logs a custom event and blocks WhatsApp without opt-in", %{conn: conn, miami: miami} do
    {:ok, view, _html} = live(authed(conn), ~p"/admin/prospects?id=#{miami.id}")

    html =
      view
      |> form("#log-form", event: %{channel: "whatsapp", outcome: "other", notes: "hi"})
      |> render_submit()

    assert html =~ "prior opt-in"

    html =
      view
      |> form("#log-form",
        event: %{
          channel: "email",
          outcome: "interested",
          notes: "Wants a booking page",
          next_action_at: Date.to_iso8601(Date.add(Date.utc_today(), 5))
        }
      )
      |> render_submit()

    assert html =~ "Wants a booking page"
    assert Directory.get_company!(miami.id).status == :contacted
  end
end
