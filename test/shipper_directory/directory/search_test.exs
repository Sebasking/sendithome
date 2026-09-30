defmodule ShipperDirectory.Directory.SearchTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Destinations, RoutePages}
  alias ShipperDirectory.Discovery.Metros

  defp published(attrs) do
    Directory.create_company!(
      Map.merge(%{status: :published, website_url: "https://example.com"}, attrs)
    )
  end

  test "Destinations.slugs_for/1 maps aliases and ignores generic regions" do
    assert Destinations.slugs_for(["T&T", "Jamaica", "Caribbean", "DR", "St. Lucia"]) ==
             ["trinidad-and-tobago", "jamaica", "dominican-republic", "st-lucia"]
  end

  test "Metros.slugs_for/2 maps cities, and Jamaica is Queens only in NY" do
    assert Metros.slugs_for(["Lauderhill", "West Palm Beach"], "FL") == ["broward", "palm-beach"]
    assert Metros.slugs_for(["Jamaica"], "NY") == ["queens"]
    assert Metros.slugs_for(["Jamaica"], nil) == []
    assert Metros.slugs_for(["NY metro", "Florida"], nil) == []
  end

  test "search keys are derived on create and update" do
    c = published(%{name: "A", city: "Brooklyn", state: "NY", destinations: ["Guyana", "T&T"]})
    assert c.metro_slugs == ["brooklyn"]
    assert c.destination_slugs == ["guyana", "trinidad-and-tobago"]

    c = Directory.update_company!(c, %{origin_metros: ["Queens"], destinations: ["Jamaica"]})
    assert c.metro_slugs == ["brooklyn", "queens"]
    assert c.destination_slugs == ["jamaica"]
  end

  test "search filters by metro, destination, and service, and only returns published" do
    a =
      published(%{
        name: "A",
        city: "Brooklyn",
        state: "NY",
        destinations: ["Guyana"],
        services: [:barrel]
      })

    b = published(%{name: "B", city: "Miami", state: "FL", destinations: ["Guyana", "Jamaica"]})

    Directory.create_company!(%{
      name: "Prospect",
      city: "Brooklyn",
      state: "NY",
      destinations: ["Guyana"],
      status: :prospect
    })

    ids = &Enum.map(&1, fn c -> c.id end)

    assert ids.(Directory.search_companies!(%{})) == [a.id, b.id]
    assert ids.(Directory.search_companies!(%{metro: "brooklyn"})) == [a.id]
    assert ids.(Directory.search_companies!(%{destination: "guyana"})) == [a.id, b.id]
    assert ids.(Directory.search_companies!(%{destination: "jamaica"})) == [b.id]
    assert ids.(Directory.search_companies!(%{service: "barrel"})) == [a.id]
    assert Directory.search_companies!(%{metro: "brooklyn", destination: "jamaica"}) == []
  end

  test "RoutePages.available/0 counts published companies per route" do
    published(%{name: "A", city: "Brooklyn", state: "NY", destinations: ["Guyana"]})
    published(%{name: "B", city: "Brooklyn", state: "NY", destinations: ["Guyana", "Jamaica"]})

    Directory.create_company!(%{
      name: "C",
      city: "Brooklyn",
      state: "NY",
      destinations: ["Haiti"],
      status: :prospect
    })

    assert [
             %{slug: "brooklyn-to-guyana", count: 2},
             %{slug: "brooklyn-to-jamaica", count: 1}
           ] = RoutePages.available()
  end

  test "RoutePages.parse/1" do
    assert {:ok, "staten-island", "trinidad-and-tobago"} =
             RoutePages.parse("staten-island-to-trinidad-and-tobago")

    assert {:ok, "north-jersey", "st-kitts-and-nevis"} =
             RoutePages.parse("north-jersey-to-st-kitts-and-nevis")

    assert :error = RoutePages.parse("brooklyn-to-atlantis")
    assert :error = RoutePages.parse("guyana")
  end
end
