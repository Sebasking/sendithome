defmodule ShipperDirectoryWeb.PageControllerTest do
  use ShipperDirectoryWeb.ConnCase

  alias ShipperDirectory.Directory

  test "GET / lists only published companies", %{conn: conn} do
    Directory.create_company!(%{
      name: "Listed Co",
      status: :published,
      website_url: "https://a.com"
    })

    Directory.create_company!(%{name: "Prospect Co", status: :prospect})

    html = conn |> get(~p"/") |> html_response(200)
    assert html =~ "Listed Co"
    refute html =~ "Prospect Co"
  end
end
