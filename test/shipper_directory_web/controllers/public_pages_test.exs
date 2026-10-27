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

  describe "home hero" do
    test "has the headline, both calls to action and the journey video", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#hero h1", "Find your Caribbean shipper")
      assert has_element?(view, ~s(#hero-find-shipper[href="/start"]))
      assert has_element?(view, ~s(#hero-browse-shippers[href="/shippers"]))
      assert has_element?(view, ~s(#hero-video[phx-hook="HeroVideo"][phx-update="ignore"]))
      assert has_element?(view, ~s(#hero-video-toggle[aria-label]))

      video = "#hero-video video"

      assert has_element?(
               view,
               ~s(#{video}[muted][loop][playsinline][preload="metadata"][poster^="/videos/journey-poster"])
             )

      refute has_element?(view, "#{video}[autoplay]")
      refute has_element?(view, "#{video}[controls]")

      sources =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("#{video} source")
        |> LazyHTML.attribute("src")

      assert length(sources) == 4
      assert Enum.all?(sources, &String.starts_with?(&1, "/videos/journey-"))
    end
  end

  describe "hero video files" do
    @videos ~w(journey-720.webm journey-720.mp4 journey-1080.webm journey-1080.mp4)

    for file <- @videos do
      test "#{file} is served with range support", %{conn: conn} do
        path = "/videos/#{unquote(file)}"
        type = if String.ends_with?(path, ".webm"), do: "video/webm", else: "video/mp4"

        conn = get(conn, path)
        assert conn.status == 200
        assert [^type <> _] = get_resp_header(conn, "content-type")

        partial = build_conn() |> put_req_header("range", "bytes=0-99") |> get(path)
        assert partial.status == 206
        assert byte_size(partial.resp_body) == 100
      end
    end

    test "the poster is served", %{conn: conn} do
      assert conn |> get("/videos/journey-poster.jpg") |> response(200)
    end

    # Digested paths carry ?vsn=d in production.
    test "versioned requests are cached as immutable", %{conn: conn} do
      conn = get(conn, "/videos/journey-720.mp4?vsn=d")
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    test "every file is within its size budget" do
      dir = Application.app_dir(:shipper_directory, "priv/static/videos")

      for {file, budget} <- [
            {"journey-720.webm", 1_000_000},
            {"journey-720.mp4", 1_000_000},
            {"journey-1080.webm", 2_000_000},
            {"journey-1080.mp4", 2_000_000}
          ] do
        assert File.stat!(Path.join(dir, file)).size < budget, "#{file} is over budget"
      end
    end
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
      |> form("#search", search: %{from: "miami", to: ""})
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
