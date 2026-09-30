defmodule ShipperDirectory.Directory.Import.SeedCsvTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Import.SeedCsv

  test "creates 17 companies from the seed list and dedupes on rerun" do
    assert %{created: 17, updated: 0} = SeedCsv.import!()
    assert %{created: 0, updated: 17} = SeedCsv.import!()

    assert length(Directory.list_companies!()) == 17
    assert length(Ash.read!(ShipperDirectory.Directory.Sighting)) == 17
  end

  test "maps the CSV's presence hint onto status" do
    SeedCsv.import!()

    assert %{status: :prospect, presence_status: :none, phone: "(475) 999-2429"} =
             Directory.get_company_by_slug!("medas-moving-and-overseas-shipping")

    assert %{status: :discovered, presence_status: :needs_review, hold_for_review: true} =
             Directory.get_company_by_slug!("quality-one-international")

    assert %{status: :discovered, presence_status: nil} =
             Directory.get_company_by_slug!("fcs-shipping-llc")

    assert length(Directory.prospects!()) == 5
  end

  test "rerun fills blanks and unions lists without clobbering status" do
    SeedCsv.import!()
    fcs = Directory.get_company_by_slug!("fcs-shipping-llc")
    Directory.set_company_status!(fcs, :published)

    SeedCsv.import_row!(%{
      "name" => "FCS Shipping",
      "hq_or_origin" => "1 Main St, Brooklyn, NY",
      "destinations" => "Grenada",
      "website" => "",
      "presence_status" => "listed",
      "source" => "Yelp",
      "notes" => "(718) 483-8006"
    })

    fcs = Directory.get_company_by_slug!("fcs-shipping-llc")
    assert fcs.status == :published
    assert fcs.address == "1 Main St"
    assert "Grenada" in fcs.destinations and "St. Lucia" in fcs.destinations
    assert "Yelp" in fcs.source and "web search" in fcs.source
  end

  test "parse_location/1" do
    assert %{address: "35 Rogers Ave", city: "Brooklyn", state: "NY"} =
             SeedCsv.parse_location("35 Rogers Ave, Brooklyn, NY")

    assert %{city: "Miami", state: "FL", origin_metros: ["Miami", "Fort Lauderdale"]} =
             SeedCsv.parse_location("Miami / Fort Lauderdale, FL")

    assert %{city: "Bridgeport", state: "CT"} =
             SeedCsv.parse_location("Bridgeport, CT (earlier Brooklyn)")

    assert %{origin_metros: ["NY metro", "Florida"]} =
             SeedCsv.parse_location("NY metro + Florida")

    assert %{origin_metros: []} = SeedCsv.parse_location("unknown")
  end

  test "parse_destinations/1 keeps multi-word islands whole" do
    assert SeedCsv.parse_destinations("Trinidad, Guyana, more") == ["Trinidad", "Guyana"]
    assert SeedCsv.parse_destinations("St. Lucia + Caribbean") == ["St. Lucia", "Caribbean"]
    assert SeedCsv.parse_destinations("Trinidad & Tobago") == ["Trinidad & Tobago"]
  end
end
