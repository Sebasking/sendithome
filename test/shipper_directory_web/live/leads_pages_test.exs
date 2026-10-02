defmodule ShipperDirectoryWeb.LeadsPagesTest do
  use ShipperDirectoryWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ShipperDirectory.Fixtures

  alias ShipperDirectory.{Directory, Leads}

  setup do
    Application.put_env(:shipper_directory, :lead_price_cents, 1500)
    on_exit(fn -> Application.put_env(:shipper_directory, :lead_price_cents, 0) end)
  end

  defp authed(conn),
    do: put_req_header(conn, "authorization", Plug.BasicAuth.encode_basic_auth("admin", "secret"))

  defp delivery_for(company) do
    {:ok, lead} =
      Leads.submit(lead_params(%{"email" => "c#{System.unique_integer()}@example.com"}), [
        company.id
      ])

    lead |> Ash.load!(:deliveries) |> Map.get(:deliveries) |> hd()
  end

  test "owner sees their requests, updates status, and disputes", %{conn: conn} do
    mine = company(%{name: "Mine", owner: "me@example.com"})
    theirs = company(%{name: "Theirs", owner: "them@example.com"})
    delivery = delivery_for(mine)
    other = delivery_for(theirs)

    owner = Ash.load!(mine, :owner, authorize?: false).owner
    conn = log_in_owner(conn, owner)

    {:ok, view, html} = live(conn, ~p"/my/leads")
    assert html =~ "Marcia"
    assert html =~ "$15.00"
    refute html =~ "delivery-#{other.id}"

    view
    |> form("#status-#{delivery.id}", %{status: "contacted"})
    |> render_change(%{"delivery_id" => delivery.id})

    assert Directory.get_lead_delivery!(delivery.id).status == :contacted

    view |> element("#delivery-#{delivery.id} button", "Dispute") |> render_click()
    view |> form("#dispute-#{delivery.id}", %{reason: "Wrong number"}) |> render_submit()

    assert %{status: :disputed, dispute_reason: "Wrong number"} =
             Directory.get_lead_delivery!(delivery.id)
  end

  test "owner turns quote requests on and off", %{conn: conn} do
    owned =
      company(%{name: "Mine", owner: "me@example.com"}) |> Directory.set_accepts_leads!(false)

    owner = Ash.load!(owned, :owner, authorize?: false).owner

    {:ok, view, html} = live(log_in_owner(conn, owner), ~p"/my/listings")
    assert html =~ "Each request costs $15.00"

    view
    |> form("#leads-#{owned.id}")
    |> render_change(%{"company_id" => owned.id, "accepts_leads" => "true"})

    assert %{accepts_leads: true, leads_terms_accepted_at: %DateTime{}} =
             Directory.get_company!(owned.id)
  end

  test "admin resolves disputes and exports the ledger", %{conn: conn} do
    a = company(%{name: "Alpha", owner: "a@example.com"})
    delivery = delivery_for(a)
    delivery_for(a)
    Directory.owner_update_lead_delivery!(delivery, %{status: :disputed, dispute_reason: "Spam"})

    {:ok, view, html} = live(authed(conn), ~p"/admin/leads")
    assert html =~ "disputes Marcia"

    view |> element("#dispute-#{delivery.id} button", "Accept") |> render_click()
    assert Directory.get_lead_delivery!(delivery.id).status == :credited

    csv = build_conn() |> authed() |> get(~p"/admin/ledger.csv") |> response(200)
    assert csv =~ "Alpha,1,15.00"
  end

  test "admin creates a placement and sees the slot limit", %{conn: conn} do
    [a, b, c] = for n <- ~w(A B C), do: company(%{name: "Co #{n}"})
    {:ok, view, _html} = live(authed(conn), ~p"/admin/placements")

    submit = fn company ->
      view
      |> form("#placement-form",
        placement: %{
          company_id: company.id,
          metro: "brooklyn",
          destination: "guyana",
          price: "99.50"
        }
      )
      |> render_submit()
    end

    submit.(a)
    submit.(b)
    assert submit.(c) =~ "slot is full"
    assert [%{price_cents: 9950} | _] = Directory.list_placements!()
  end
end
