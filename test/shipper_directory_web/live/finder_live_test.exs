defmodule ShipperDirectoryWeb.FinderLiveTest do
  use ShipperDirectoryWeb.ConnCase

  import Phoenix.LiveViewTest
  import ShipperDirectory.Fixtures

  alias ShipperDirectory.Analytics.{FlowAnswerEvent, ImpressionEvent}
  alias ShipperDirectory.Directory

  defp answers, do: Enum.map(Ash.read!(FlowAnswerEvent), &{&1.step, &1.answer, &1.source_code})
  defp impressions, do: Ash.read!(ImpressionEvent)

  defp jamaica_shippers(n, attrs \\ %{}) do
    for i <- 1..n,
        do: verified_company(Map.merge(%{name: "JA #{i}", destinations: ["Jamaica"]}, attrs))
  end

  describe "destination step" do
    test "renders from its URL with every destination in order", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/start")

      assert has_element?(view, "nav[aria-label='Choose a destination']")

      codes =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("#destination-list a")
        |> LazyHTML.attribute("id")

      assert codes == ~w(destination-jm destination-gy destination-tt destination-bb
                         destination-ht destination-other)

      assert has_element?(view, "#browse-all[href='/shippers']")
      assert page_title(view) =~ "Where’s your barrel headed?"
    end

    test "carries src and UTM params on every link", %{conn: conn} do
      put_christmas_season(false)
      {:ok, view, _html} = live(conn, ~p"/start?src=store-1&utm_content=logo_b")

      assert has_element?(
               view,
               "#destination-jm[href='/shippers?src=store-1&to=jm&utm_content=logo_b']"
             )

      assert has_element?(view, "#browse-all[href='/shippers?src=store-1&utm_content=logo_b']")
    end

    test "in season, a destination leads to the timing question and logs the answer", %{
      conn: conn
    } do
      put_christmas_season(true)
      {:ok, view, _html} = live(conn, ~p"/start?src=store-1")

      view |> element("#destination-jm") |> render_click()
      assert_patch(view, ~p"/start/when?src=store-1&to=jm")

      assert has_element?(view, "#destination-chip", "Shipping to Jamaica")
      assert has_element?(view, "#flow-step", "Step 2 of 2")
      assert answers() == [{:destination, "jm", "store-1"}]
    end

    test "out of season, a destination goes straight to results", %{conn: conn} do
      put_christmas_season(false)
      jamaica_shippers(3)
      {:ok, view, _html} = live(conn, ~p"/start")

      view |> element("#destination-jm") |> render_click()
      assert_patch(view, ~p"/shippers?to=jm")
      assert has_element?(view, "#flow-heading", "Shippers to Jamaica")
      assert answers() == [{:destination, "jm", nil}]
    end
  end

  describe "timing step" do
    setup do
      put_christmas_season(true)
      jamaica_shippers(3, %{christmas_cutoff_date: Date.add(Date.utc_today(), 7)})
      :ok
    end

    test "renders from its URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/start/when?to=jm")

      assert has_element?(view, "#timing-christmas[href='/shippers?to=jm&when=christmas']")
      assert has_element?(view, "#timing-any[href='/shippers?to=jm&when=any']")
      assert has_element?(view, "#timing-skip")
      assert has_element?(view, "#cutoff-notice")
      assert has_element?(view, "#flow-back[href='/start']")
      # Opening a URL directly isn't an answer.
      assert answers() == []
    end

    test "before Christmas logs the answer and filters results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/start/when?to=jm&src=s1")

      view |> element("#timing-christmas") |> render_click()
      assert_patch(view, ~p"/shippers?src=s1&to=jm&when=christmas")

      assert has_element?(view, "#remove-timing[aria-label='Remove filter: Before Christmas']")
      assert has_element?(view, "#results-summary", "3 shippers · makes Christmas")
      assert answers() == [{:timing, "christmas", "s1"}]
    end

    test "skip behaves like no rush and is logged as skip", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/start/when?to=jm")

      view |> element("#timing-skip") |> render_click()
      refute has_element?(view, "#remove-timing")
      assert answers() == [{:timing, "skip", nil}]
    end

    test "an unknown destination redirects to the first step", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/start?src=s1"}}} =
               live(conn, ~p"/start/when?to=zz&src=s1")
    end

    test "out of season redirects to results", %{conn: conn} do
      put_christmas_season(false)

      assert {:error, {:live_redirect, %{to: "/shippers?to=jm"}}} =
               live(conn, ~p"/start/when?to=jm")
    end
  end

  describe "results" do
    test "a shared URL renders on its own, ordered by name", %{conn: conn} do
      verified_company(%{
        name: "Zed Shipping",
        destinations: ["Jamaica"],
        neighborhood: "Flatbush"
      })

      verified_company(%{name: "Able Shipping", destinations: ["Jamaica"], phone: "7185550101"})
      verified_company(%{name: "Cargo Co", destinations: ["Jamaica"]})
      verified_company(%{name: "Guyana Only", destinations: ["Guyana"]})

      {:ok, view, html} = live(conn, ~p"/shippers?to=jm")

      assert has_element?(view, "#flow-heading", "Shippers to Jamaica")
      assert has_element?(view, "#results-summary", "3 shippers")
      refute html =~ "Guyana Only"

      names =
        html
        |> LazyHTML.from_document()
        |> LazyHTML.query("#shippers article h2")
        |> Enum.map(&LazyHTML.text/1)
        |> Enum.map(&String.trim/1)

      assert names == ["Able Shipping", "Cargo Co", "Zed Shipping"]
      assert html =~ "Flatbush"
      assert answers() == []
    end

    test "canonical URL leaves out src and UTM params", %{conn: conn} do
      html = conn |> get(~p"/shippers?to=jm&src=s1&utm_content=logo_a") |> html_response(200)
      assert html =~ ~s(rel="canonical" href="#{url(~p"/shippers?to=jm")}")
    end

    test "removing a chip updates the URL and the list", %{conn: conn} do
      put_christmas_season(true)
      cutoff = Date.add(Date.utc_today(), 7)
      jamaica_shippers(3, %{christmas_cutoff_date: cutoff})
      verified_company(%{name: "Guyana Line", christmas_cutoff_date: cutoff})

      {:ok, view, _html} = live(conn, ~p"/shippers?to=jm&when=christmas&src=s1")
      refute has_element?(view, "article", "Guyana Line")

      view |> element("#remove-destination") |> render_click()
      assert_patch(view, ~p"/shippers?src=s1&when=christmas")
      assert has_element?(view, "#flow-heading", "All shippers")
      assert has_element?(view, "article", "Guyana Line")
      assert has_element?(view, "#remove-timing")
      refute has_element?(view, "#remove-destination")
    end

    test "when=christmas is ignored outside the season", %{conn: conn} do
      put_christmas_season(false)
      jamaica_shippers(3)

      {:ok, view, _html} = live(conn, ~p"/shippers?to=jm&when=christmas")
      refute has_element?(view, "#remove-timing")
      assert has_element?(view, "#results-summary", "3 shippers")
    end

    test "thin results show the listings and the suggest panel", %{conn: conn} do
      jamaica_shippers(1)
      {:ok, view, _html} = live(conn, ~p"/shippers?to=jm")

      assert has_element?(view, "#shippers article", "JA 1")
      assert has_element?(view, "#thin-results", "still adding shippers to Jamaica")
      assert has_element?(view, "#suggest-shipper")
      assert has_element?(view, "#all-destinations[href='/shippers']")
      refute has_element?(view, "#suggest-footer")
    end

    test "zero results show the panel only", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/shippers?to=ht")

      refute has_element?(view, "#shippers article")
      assert has_element?(view, "#thin-results", "still adding shippers to Haiti")
    end

    test "to=other shows every shipper and invites a destination suggestion", %{conn: conn} do
      verified_company(%{name: "Guyana Line"})
      {:ok, view, _html} = live(conn, ~p"/shippers?to=other")

      assert has_element?(view, "#flow-heading", "All shippers")
      assert has_element?(view, "#suggest-destination")
      assert has_element?(view, "article", "Guyana Line")
    end

    test "an unknown destination is ignored", %{conn: conn} do
      verified_company(%{name: "Guyana Line"})
      {:ok, view, _html} = live(conn, ~p"/shippers?to=zz")
      assert has_element?(view, "#flow-heading", "All shippers")
      assert has_element?(view, "article", "Guyana Line")
    end

    test "contact buttons go through /go and only for channels the shipper has", %{conn: conn} do
      company =
        verified_company(%{
          name: "Phone Only",
          destinations: ["Jamaica"],
          phone: "(718) 555-0101"
        })

      {:ok, view, _html} = live(conn, ~p"/shippers?to=jm&src=s1&utm_content=logo_b")

      card = "#shippers-#{company.id}"

      assert has_element?(
               view,
               "#{card}-call[href='/go/#{company.slug}/call?src=s1&to=jm&utm_content=logo_b']"
             )

      refute has_element?(view, "#{card}-whatsapp")
    end

    test "a sponsored shipper is labeled and logged as a sponsored impression", %{conn: conn} do
      source =
        Directory.create_sticker_source!(%{
          code: "store-9",
          label: "Test store",
          area: "brooklyn"
        })

      [_a, b, _c] = jamaica_shippers(3, %{whatsapp_number: "3475550102"})
      today = Date.utc_today()

      Directory.create_placement!(%{
        company_id: b.id,
        metro: "brooklyn",
        destination: "jamaica",
        starts_on: today,
        ends_on: Date.add(today, 10)
      })

      {:ok, view, _html} = live(conn, ~p"/shippers?to=jm&src=#{source.code}")

      assert has_element?(view, "#sponsored-shipper", "Sponsored")
      assert has_element?(view, "#sponsored-shipper", b.name)
      refute has_element?(view, "#shippers article", b.name)
      assert has_element?(view, "#sponsored-shipper-whatsapp[href*='sponsored=1']")
      assert has_element?(view, "#results-summary", "3 shippers near Brooklyn")

      # One impression per shipper shown, from the connected mount only.
      events = impressions()
      assert length(events) == 3
      assert [%{company_id: id}] = Enum.filter(events, & &1.sponsored)
      assert id == b.id
      assert Enum.all?(events, &(&1.destination_code == "jm" and &1.source_code == "store-9"))
      assert Enum.all?(events, &(&1.area_slug == "brooklyn"))
    end

    test "says when the sticker's area had too few shippers", %{conn: conn} do
      source =
        Directory.create_sticker_source!(%{
          code: "store-q",
          label: "Queens store",
          area: "queens"
        })

      jamaica_shippers(3)
      {:ok, view, _html} = live(conn, ~p"/shippers?to=jm&src=#{source.code}")
      assert has_element?(view, "#results-summary", "3 shippers in all areas")
    end
  end

  test "bots aren't logged", %{conn: conn} do
    jamaica_shippers(3)

    conn = put_req_header(conn, "user-agent", "Mozilla/5.0 (compatible; Googlebot/2.1)")
    {:ok, view, _html} = live(conn, ~p"/start")
    view |> element("#destination-other") |> render_click()

    assert answers() == []
    assert impressions() == []
  end

  test "flow pages set no cookies and use the session-less socket", %{conn: conn} do
    put_christmas_season(true)
    jamaica_shippers(3)

    for path <- [~p"/start", ~p"/shippers?to=jm", ~p"/start/when?to=jm"] do
      conn = get(conn, path)
      assert get_resp_header(conn, "set-cookie") == [], "#{path} set a cookie"
      assert html_response(conn, 200) =~ ~s(name="live-socket-path" content="/flow/live")
    end
  end
end
