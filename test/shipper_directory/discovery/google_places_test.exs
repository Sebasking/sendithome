defmodule ShipperDirectory.Discovery.GooglePlacesTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.GooglePlaces

  defp stub_places(places) do
    Req.Test.stub(GooglePlaces, fn conn ->
      assert ["test-key"] = Plug.Conn.get_req_header(conn, "x-goog-api-key")
      Req.Test.json(conn, %{"places" => places})
    end)
  end

  defp place(attrs) do
    Map.merge(
      %{
        "id" => "ChIJplace",
        "displayName" => %{"text" => "Barrel-It Caribbean Shipping"},
        "businessStatus" => "OPERATIONAL"
      },
      attrs
    )
  end

  defp company(attrs \\ %{}) do
    Directory.create_company!(
      Map.merge(%{name: "Barrel-It Caribbean Shipping", city: "Brooklyn", state: "NY"}, attrs)
    )
  end

  test "no website on Google makes a prospect and stores only the place ID and flag" do
    stub_places([place(%{"nationalPhoneNumber" => "(718) 555-0100"})])
    # Matched by name; Google's phone is never copied over ours.
    {:ok, c} = GooglePlaces.enrich(company(%{phone: "(718) 555-0199"}))

    assert %{
             google_place_id: "ChIJplace",
             google_has_website: false,
             presence_status: :none,
             status: :prospect,
             phone: "(718) 555-0199"
           } = c

    assert c.google_checked_at
  end

  test "a listed website goes to review for a person to enter (never stores Google's URL)" do
    stub_places([place(%{"websiteUri" => "https://barrelit.example"})])
    {:ok, c} = GooglePlaces.enrich(company())

    assert %{google_has_website: true, presence_status: :needs_review, website_url: nil} = c
    assert c.review_reason =~ "lists a website"
  end

  test "matches by phone when the name differs" do
    stub_places([
      place(%{"id" => "wrong", "displayName" => %{"text" => "UPS Store"}}),
      place(%{
        "id" => "right",
        "displayName" => %{"text" => "BIC Shipping"},
        "nationalPhoneNumber" => "718-555-0100"
      })
    ])

    {:ok, c} = GooglePlaces.enrich(company(%{phone: "(718) 555-0100"}))
    assert c.google_place_id == "right"
  end

  test "no confident match goes to review" do
    stub_places([place(%{"displayName" => %{"text" => "The UPS Store"}})])
    {:ok, c} = GooglePlaces.enrich(company())
    assert %{google_place_id: nil, presence_status: :needs_review} = c
    assert c.google_checked_at
  end

  test "permanently closed leaves the prospect list and goes to review" do
    stub_places([place(%{"businessStatus" => "CLOSED_PERMANENTLY"})])
    {:ok, c} = GooglePlaces.enrich(company(%{status: :prospect, phone: "(718) 555-0199"}))

    assert %{presence_status: :needs_review, status: :discovered} = c
    assert c.review_reason =~ "permanently closed"
    refute Enum.any?(Directory.prospects!(), &(&1.id == c.id))
  end

  test "permanently closed unpublishes a listing even with a website" do
    stub_places([place(%{"businessStatus" => "CLOSED_PERMANENTLY"})])

    c =
      company(%{
        website_url: "https://barrelit.example",
        presence_status: :listed,
        status: :published
      })

    assert {:ok, %{status: :discovered, presence_status: :needs_review}} = GooglePlaces.enrich(c)
  end

  test "permanently closed leaves CRM statuses alone" do
    stub_places([place(%{"businessStatus" => "CLOSED_PERMANENTLY"})])
    assert {:ok, %{status: :contacted}} = GooglePlaces.enrich(company(%{status: :contacted}))
  end

  test "companies that already have a website keep their presence status" do
    stub_places([place(%{})])

    c =
      company(%{
        website_url: "https://barrelit.example",
        presence_status: :listed,
        status: :published
      })

    {:ok, c} = GooglePlaces.enrich(c)
    assert %{presence_status: :listed, status: :published, google_place_id: "ChIJplace"} = c
  end

  test "missing API key" do
    Application.put_env(:shipper_directory, :google_places_api_key, nil)
    on_exit(fn -> Application.put_env(:shipper_directory, :google_places_api_key, "test-key") end)
    assert {:error, :missing_api_key} = GooglePlaces.search("anything")
  end
end
