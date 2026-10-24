defmodule ShipperDirectoryWeb.FlowControllersTest do
  use ShipperDirectoryWeb.ConnCase

  import ShipperDirectory.Fixtures

  alias ShipperDirectory.Analytics.{ContactClickEvent, ScanEvent}
  alias ShipperDirectory.Repo

  @googlebot "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  describe "GET /s/:code" do
    test "logs one scan and redirects into the flow", %{conn: conn} do
      conn = get(conn, ~p"/s/store-123?utm_campaign=launch")

      assert redirected_to(conn) == ~p"/start?src=store-123&utm_campaign=launch"
      assert get_resp_header(conn, "set-cookie") == []

      assert [%{source_code: "store-123", utm_campaign: "launch"}] = Ash.read!(ScanEvent)
    end

    test "unknown codes still redirect and are logged raw", %{conn: conn} do
      conn = get(conn, ~p"/s/Not-A-Store")
      assert redirected_to(conn) == ~p"/start?src=Not-A-Store"
      assert [%{source_code: "Not-A-Store"}] = Ash.read!(ScanEvent)
    end

    test "bots are redirected but not logged", %{conn: conn} do
      conn = conn |> put_req_header("user-agent", @googlebot) |> get(~p"/s/store-123")
      assert redirected_to(conn) == ~p"/start?src=store-123"
      assert Ash.read!(ScanEvent) == []
    end
  end

  describe "legacy sticker URL" do
    test "/?utm_source=sticker logs one scan and redirects with UTM params", %{conn: conn} do
      conn = get(conn, "/?utm_source=sticker&utm_content=logo_a")

      assert redirected_to(conn) == ~p"/start?utm_content=logo_a&utm_source=sticker"
      assert get_resp_header(conn, "set-cookie") == []

      assert [%{source_code: nil, utm_source: "sticker", utm_content: "logo_a"}] =
               Ash.read!(ScanEvent)
    end

    test "the home page is untouched otherwise", %{conn: conn} do
      assert conn |> get(~p"/?utm_source=newsletter") |> html_response(200)
      assert Ash.read!(ScanEvent) == []
    end
  end

  describe "GET /go/:slug/:channel" do
    setup do
      company =
        verified_company(%{
          name: "Island Barrels",
          phone: "(718) 555-0101",
          whatsapp_number: "+1 347-555-0102",
          website_url: "https://islandbarrels.example"
        })

      %{company: company}
    end

    test "logs one contact click and redirects to the channel", %{conn: conn, company: company} do
      conn =
        get(
          conn,
          ~p"/go/#{company.slug}/call?sponsored=1&to=jm&src=store-1&utm_content=logo_b"
        )

      assert redirected_to(conn) == "tel:+17185550101"
      assert get_resp_header(conn, "set-cookie") == []

      assert [event] = Ash.read!(ContactClickEvent)
      assert event.company_id == company.id
      assert event.channel == :call
      assert event.sponsored

      assert {event.destination_code, event.source_code, event.utm_content} ==
               {"jm", "store-1", "logo_b"}
    end

    test "whatsapp and website targets", %{conn: conn, company: company} do
      assert conn |> get(~p"/go/#{company.slug}/whatsapp") |> redirected_to() ==
               "https://wa.me/13475550102"

      assert conn |> get(~p"/go/#{company.slug}/website") |> redirected_to() ==
               "https://islandbarrels.example"

      assert [%{sponsored: false}, %{sponsored: false}] = Ash.read!(ContactClickEvent)
    end

    test "404 on an unknown shipper, channel, or a channel the shipper lacks", %{
      conn: conn,
      company: company
    } do
      no_whatsapp = verified_company(%{name: "No WhatsApp"})
      prospect = company(%{name: "Prospect Co", phone: "7185550199", status: :prospect})

      for path <- [
            ~p"/go/nobody/call",
            ~p"/go/#{company.slug}/email",
            ~p"/go/#{no_whatsapp.slug}/whatsapp",
            ~p"/go/#{prospect.slug}/call"
          ] do
        assert_error_sent 404, fn -> get(conn, path) end
      end

      assert Ash.read!(ContactClickEvent) == []
    end

    test "bots are redirected but not logged", %{conn: conn, company: company} do
      conn = conn |> put_req_header("user-agent", @googlebot) |> get(~p"/go/#{company.slug}/call")
      assert redirected_to(conn) == "tel:+17185550101"
      assert Ash.read!(ContactClickEvent) == []
    end
  end

  test "no event table can hold an IP address, user agent or cookie" do
    columns =
      Repo.query!("""
      SELECT column_name FROM information_schema.columns
      WHERE table_name IN ('scan_events', 'flow_answer_events', 'impression_events', 'contact_click_events')
      """).rows
      |> List.flatten()

    for forbidden <- ~w(ip remote_ip ip_address user_agent cookie session_id device_id) do
      refute forbidden in columns
    end
  end
end
