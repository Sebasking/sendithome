defmodule ShipperDirectoryWeb.BrandController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectoryWeb.Brand

  # Browsers and crawlers request /favicon.ico directly, so serve the active variant's icon.
  def favicon(conn, _params) do
    conn
    |> put_resp_content_type("image/x-icon", nil)
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> send_file(200, Brand.asset_file("favicon.ico"))
  end
end
