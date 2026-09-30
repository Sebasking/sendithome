defmodule ShipperDirectory.Discovery.FmcTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.{Fmc, Metros}

  @headers [
    "Organization Number",
    "Name",
    "Street 1",
    "Street 2",
    "City",
    "State",
    "Zip",
    "Nation",
    "Phone",
    "License Number",
    "NVOCC DBA Name 1",
    "NVOCC DBA Name 2",
    "FF DBA Name 1",
    "FF DBA Name 2"
  ]

  defp row(values) do
    defaults = %{
      "Street 2" => "",
      "Nation" => "UNITED STATES",
      "NVOCC DBA Name 1" => "",
      "NVOCC DBA Name 2" => "",
      "FF DBA Name 1" => "",
      "FF DBA Name 2" => ""
    }

    Map.merge(defaults, values)
  end

  defp dennis do
    row(%{
      "Organization Number" => "015070",
      "Name" => "DENNIS SHIPPING CO., INC.",
      "Street 1" => "1124-28 UTICA AVENUE",
      "City" => "BROOKLYN",
      "State" => "NY",
      "Zip" => "11203",
      "Phone" => "(718) 451-3617",
      "License Number" => "015070"
    })
  end

  defp standard_caribbean do
    row(%{
      "Organization Number" => "020001",
      "Name" => "STANDARD CARIBBEAN SHIPPING, INC.",
      "Street 1" => "1 FLATBUSH AVENUE",
      "City" => "BROOKLYN",
      "State" => "NY",
      "Zip" => "11217",
      "Phone" => "(718) 209-1100",
      "License Number" => "020001"
    })
  end

  defp miami_forwarder do
    row(%{
      "Organization Number" => "030001",
      "Name" => "SUNSHINE CARGO LLC",
      "Street 1" => "1 NW 1ST STREET",
      "City" => "MIAMI",
      "State" => "FL",
      "Zip" => "33101",
      "Phone" => "(305) 555-0100",
      "License Number" => "030001"
    })
  end

  test "parse_rows/1 skips the banner and keys rows by header" do
    rows = [["List as of: 2026-09-29"], @headers, ["000142", "YOUNG SEA CARGO CORP.", 75_000.0]]

    assert [
             %{
               "Organization Number" => "000142",
               "Name" => "YOUNG SEA CARGO CORP.",
               "Street 1" => "75000"
             }
           ] =
             Fmc.parse_rows(rows)
  end

  test "caribbean_name?/1 checks names and DBAs, ignoring New York islands" do
    assert Fmc.caribbean_name?(standard_caribbean())
    assert Fmc.caribbean_name?(row(%{"Name" => "TRANS-JAM EXPRESS SHIPPING COMPANY, INC."}))
    assert Fmc.caribbean_name?(row(%{"Name" => "ACME INC", "FF DBA Name 1" => "ISLANDS EXPRESS"}))
    refute Fmc.caribbean_name?(dennis())
    refute Fmc.caribbean_name?(row(%{"Name" => "LONG ISLAND LOGISTICS INC"}))
    refute Fmc.caribbean_name?(row(%{"Name" => "LUCIANO SHIPPING, INC."}))
  end

  test "Metros.for_address/2 uses ZIP prefixes" do
    assert %{slug: "queens"} = Metros.for_address("NY", "11434")
    assert %{slug: "brooklyn"} = Metros.for_address("NY", "11203-1234")
    assert %{slug: "north-jersey"} = Metros.for_address("NJ", "7017")
    assert nil == Metros.for_address("PA", "19312")
  end

  test "discovers licensees in the requested metros only" do
    stats = Fmc.import!([dennis(), standard_caribbean(), miami_forwarder()], metros: ["brooklyn"])
    assert %{"created" => 2, "auto_confirmed" => 1} = stats

    assert %{needs_triage: false, fmc_license_no: "020001", origin_metros: ["Brooklyn"]} =
             Directory.get_company_by_slug!("standard-caribbean-shipping-inc")

    assert %{
             needs_triage: true,
             name: "Dennis Shipping Co., Inc.",
             address: "1124-28 Utica Avenue"
           } =
             Directory.get_company_by_slug!("dennis-shipping-co-inc")
  end

  test "rerun creates nothing and excluded companies stay excluded" do
    Fmc.import!([dennis()], metros: ["brooklyn"])
    dennis = Directory.get_company_by_slug!("dennis-shipping-co-inc")
    Directory.exclude_company!(dennis)

    assert %{"created" => 0, "updated" => 1} = Fmc.import!([dennis()], metros: ["brooklyn"])
    assert %{status: :excluded} = Directory.get_company!(dennis.id)
  end

  test "cross-references an existing company by exact name and fills its blanks" do
    seed = Directory.create_company!(%{name: "Dennis Shipping", status: :published})

    assert %{"linked" => 1, "created" => 0} = Fmc.import!([dennis()], metros: ["brooklyn"])

    assert %{
             fmc_license_no: "015070",
             phone: "(718) 451-3617",
             status: :published,
             source: source
           } =
             Directory.get_company!(seed.id)

    assert "fmc" in source
    assert length(Directory.list_companies!()) == 1
  end

  test "cross-references by phone even when names differ" do
    seed =
      Directory.create_company!(%{name: "Quality One International", phone: "(718) 231-1909"})

    quality_one =
      row(%{
        "Organization Number" => "022540",
        "Name" => "QUALITY ONE INTERNATIONAL SHIPPING EXPRESS, CORP.",
        "Street 1" => "1476 EAST 222 STREET",
        "City" => "BRONX",
        "State" => "NY",
        "Zip" => "10469",
        "Phone" => "(718) 231-1909",
        "License Number" => "022540"
      })

    Fmc.import!([quality_one], metros: [])

    assert %{fmc_license_no: "022540", address: "1476 East 222 Street"} =
             Directory.get_company!(seed.id)
  end
end
