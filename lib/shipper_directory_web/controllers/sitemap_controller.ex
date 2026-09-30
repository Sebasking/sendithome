defmodule ShipperDirectoryWeb.SitemapController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.RoutePages

  def index(conn, _params) do
    urls =
      [url(~p"/"), url(~p"/ship-barrel")] ++
        Enum.map(RoutePages.available(), &url(~p"/ship-barrel/#{&1.slug}")) ++
        Enum.map(Directory.published_companies!(), &url(~p"/shippers/#{&1.slug}"))

    xml = [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      Enum.map(urls, &["  <url><loc>", Plug.HTML.html_escape(&1), "</loc></url>\n"]),
      "</urlset>\n"
    ]

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  def robots(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, """
    User-agent: *
    Disallow: /admin

    Sitemap: #{url(~p"/sitemap.xml")}
    """)
  end
end
