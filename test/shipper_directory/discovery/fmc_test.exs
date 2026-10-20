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

  describe "import_scored!/2" do
    defp scored(row, tier, kw_dest \\ ""),
      do: Map.merge(row, %{"tier" => tier, "kw_dest" => kw_dest})

    test "keeps US rows at tier B or better, in any metro, skipping triage" do
      foreign =
        row(%{
          "Organization Number" => "040001",
          "Name" => "PORT OF SPAIN CARGO LTD.",
          "City" => "PORT OF SPAIN",
          "Nation" => "TRINIDAD AND TOBAGO",
          "License Number" => ""
        })

      records = [
        scored(miami_forwarder(), "A_strong", "ANTIGUA;ST. KITTS;CAICOS"),
        scored(dennis(), "B_likely_area"),
        scored(standard_caribbean(), "C_weak"),
        scored(foreign, "A_strong")
      ]

      assert %{"selected" => 2, "created" => 2} = Fmc.import_scored!(records)

      assert %{
               needs_triage: false,
               status: :discovered,
               origin_metros: ["Miami"],
               destinations: ["Antigua & Barbuda", "St. Kitts & Nevis", "Caicos"]
             } = Directory.get_company_by_slug!("sunshine-cargo-llc")

      assert %{needs_triage: false} = Directory.get_company_by_slug!("dennis-shipping-co-inc")
      assert {:error, _} = Directory.get_company_by_slug("standard-caribbean-shipping-inc")
      assert {:error, _} = Directory.get_company_by_slug("port-of-spain-cargo-ltd")
    end

    test "--min-tier A keeps only A, and a rerun creates nothing" do
      records = [scored(miami_forwarder(), "A_strong"), scored(dennis(), "B_likely_area")]

      assert %{"selected" => 1, "created" => 1} = Fmc.import_scored!(records, min_tier: "a")
      assert %{"created" => 0, "updated" => 1} = Fmc.import_scored!(records, min_tier: "A")
    end

    test "updates a company the regular FMC import already made" do
      Fmc.import!([dennis()], metros: ["brooklyn"])

      assert %{"created" => 0, "updated" => 1} =
               Fmc.import_scored!([scored(dennis(), "B_likely_area")])
    end

    test "rejects an unknown tier" do
      assert_raise ArgumentError, fn -> Fmc.import_scored!([], min_tier: "E") end
    end
  end
end
