defmodule ShipperDirectoryWeb.BrandTest do
  # Changes app env, so it can't run alongside other tests.
  use ShipperDirectoryWeb.ConnCase, async: false

  alias ShipperDirectoryWeb.Brand

  setup do
    original = Application.get_env(:shipper_directory, :logo_variant)
    on_exit(fn -> Application.put_env(:shipper_directory, :logo_variant, original) end)
  end

  for variant <- Brand.variants() do
    describe "logo variant #{variant}" do
      setup do
        Application.put_env(:shipper_directory, :logo_variant, unquote(variant))
      end

      test "layout uses that variant's logo and icons", %{conn: conn} do
        html = conn |> get(~p"/ship-barrel") |> html_response(200)
        doc = LazyHTML.from_document(html)
        prefix = "/images/brand/#{unquote(variant)}/"

        logo_srcs = doc |> LazyHTML.query("#site-logo img") |> LazyHTML.attribute("src")
        icon_hrefs = doc |> LazyHTML.query("link[rel=icon]") |> LazyHTML.attribute("href")

        assert length(logo_srcs) == 4
        assert Enum.all?(logo_srcs ++ icon_hrefs, &String.starts_with?(&1, prefix))
      end

      test "every brand asset exists on disk" do
        for file <- ~w(lockup.svg lockup-reversed.svg mark.svg mark-reversed.svg
                       favicon.svg favicon.ico apple-touch-icon.png) do
          assert File.exists?(Brand.asset_file(file)), "missing #{file}"
        end
      end

      test "/favicon.ico serves that variant's icon", %{conn: conn} do
        conn = get(conn, "/favicon.ico")

        assert response(conn, 200) == File.read!(Brand.asset_file("favicon.ico"))
        assert get_resp_header(conn, "content-type") == ["image/x-icon"]
      end
    end
  end

  test "rejects an unknown variant" do
    Application.put_env(:shipper_directory, :logo_variant, :c)
    assert_raise ArgumentError, fn -> Brand.logo_variant() end
  end
end
