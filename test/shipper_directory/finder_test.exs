defmodule ShipperDirectory.FinderTest do
  # Not async: the fixture names (Alpha, Beta...) collide on unique slugs
  # with other async tests and deadlock.
  use ShipperDirectory.DataCase

  import ShipperDirectory.Fixtures

  alias ShipperDirectory.{Directory, Finder}

  defp names(companies), do: Enum.map(companies, & &1.name)
  defp search(args), do: args |> Directory.directory_search!() |> names()
  defp destination(code), do: Directory.get_active_destination!(code)

  defp place(company, attrs) do
    today = Date.utc_today()

    Directory.create_placement!(
      Map.merge(
        %{
          company_id: company.id,
          metro: "brooklyn",
          destination: "guyana",
          starts_on: Date.add(today, -1),
          ends_on: Date.add(today, 30)
        },
        attrs
      )
    )
  end

  describe "directory_search" do
    test "only published, phone-verified companies, by name" do
      verified_company(%{name: "Beta"})
      verified_company(%{name: "Alpha"})
      company(%{name: "Unverified"})
      verified_company(%{name: "Prospect"}) |> Directory.set_company_status!(:prospect)

      assert search(%{}) == ["Alpha", "Beta"]
    end

    test "destination code filter; unknown codes and other add none" do
      verified_company(%{name: "Guyana Line", destinations: ["Guyana"]})
      verified_company(%{name: "JA Line", destinations: ["Jamaica"]})

      assert search(%{destination_code: "gy"}) == ["Guyana Line"]
      assert search(%{destination_code: "jm"}) == ["JA Line"]
      assert search(%{destination_code: "other"}) == ["Guyana Line", "JA Line"]
      assert search(%{destination_code: "zz"}) == ["Guyana Line", "JA Line"]
    end

    test "area filter" do
      verified_company(%{name: "Brooklyn Co", city: "Brooklyn"})
      verified_company(%{name: "Queens Co", city: "Queens"})

      assert search(%{area_slug: "queens"}) == ["Queens Co"]
    end

    test "christmas keeps cutoffs today or later and excludes unknown cutoffs" do
      today = Date.utc_today()
      verified_company(%{name: "Today", christmas_cutoff_date: today})
      verified_company(%{name: "Later", christmas_cutoff_date: Date.add(today, 5)})
      verified_company(%{name: "Missed", christmas_cutoff_date: Date.add(today, -1)})
      verified_company(%{name: "Unknown"})

      assert search(%{when: :christmas}) == ["Later", "Today"]
      assert search(%{when: :any}) == ["Later", "Missed", "Today", "Unknown"]
    end

    test "filters combine" do
      cutoff = Date.add(Date.utc_today(), 5)

      verified_company(%{
        name: "Match",
        city: "Queens",
        destinations: ["Jamaica"],
        christmas_cutoff_date: cutoff
      })

      verified_company(%{
        name: "Wrong area",
        destinations: ["Jamaica"],
        christmas_cutoff_date: cutoff
      })

      verified_company(%{name: "Wrong place", city: "Queens", christmas_cutoff_date: cutoff})
      verified_company(%{name: "No cutoff", city: "Queens", destinations: ["Jamaica"]})

      assert search(%{destination_code: "jm", area_slug: "queens", when: :christmas}) == ["Match"]
    end
  end

  describe "search/4" do
    test "keeps the area when enough shippers serve it" do
      for n <- 1..3, do: verified_company(%{name: "Queens #{n}", city: "Queens"})
      verified_company(%{name: "Brooklyn 1"})

      result = Finder.search(nil, "queens", :any)
      assert names(result.shippers) == ["Queens 1", "Queens 2", "Queens 3"]
      assert result.area == "queens"
      refute result.area_fallback?
    end

    test "falls back to all areas when the area is thin" do
      verified_company(%{name: "Queens 1", city: "Queens"})
      verified_company(%{name: "Brooklyn 1"})

      result = Finder.search(nil, "queens", :any)
      assert names(result.shippers) == ["Brooklyn 1", "Queens 1"]
      assert result.area == nil
      assert result.area_fallback?
      assert result.count == 2
    end

    test "one eligible sponsor fills the featured slot and leaves the regular list" do
      [_a, b, _c] = for n <- ~w(Alpha Beta Gamma), do: verified_company(%{name: n})
      place(b, %{})

      result = Finder.search(destination("gy"), "brooklyn", :any)
      assert result.sponsored.id == b.id
      assert names(result.shippers) == ["Alpha", "Gamma"]
      assert result.count == 3
    end

    test "sponsors must match area, dates and destination, and pass every filter" do
      today = Date.utc_today()
      for n <- ~w(Alpha Beta Gamma), do: verified_company(%{name: n})

      sponsor =
        verified_company(%{name: "Sponsor", destinations: ["Guyana", "Jamaica"]})

      place(sponsor, %{})

      # Different area: no sponsor, and none without a sticker area at all.
      refute Finder.search(destination("gy"), "queens", :any).sponsored
      refute Finder.search(destination("gy"), nil, :any).sponsored
      # A Guyana placement doesn't sponsor Jamaica, even though it ships there.
      refute Finder.search(destination("jm"), "brooklyn", :any).sponsored
      # Fails the Christmas filter (no cutoff date).
      refute Finder.search(destination("gy"), "brooklyn", :christmas).sponsored
      # Outside the placement's dates.
      refute Finder.search(destination("gy"), "brooklyn", :any, Date.add(today, 60)).sponsored

      assert Finder.search(destination("gy"), "brooklyn", :any).sponsored.id == sponsor.id
    end

    test "an all-destinations placement never shows a sponsor who doesn't serve the destination" do
      for n <- ~w(Alpha Beta Gamma), do: verified_company(%{name: n, destinations: ["Jamaica"]})
      sponsor = verified_company(%{name: "Sponsor", destinations: ["Guyana"]})
      place(sponsor, %{destination: nil})

      refute Finder.search(destination("jm"), "brooklyn", :any).sponsored
      assert Finder.search(destination("gy"), "brooklyn", :any).sponsored.id == sponsor.id
      assert Finder.search(nil, "brooklyn", :any).sponsored.id == sponsor.id
    end

    test "several eligible sponsors rotate by day; regular order never changes" do
      [a, b, c] = for n <- ~w(Alpha Beta Gamma), do: verified_company(%{name: n})
      place(a, %{})
      place(c, %{})
      today = Date.utc_today()

      day1 = Finder.search(destination("gy"), "brooklyn", :any, today)
      day2 = Finder.search(destination("gy"), "brooklyn", :any, Date.add(today, 1))

      assert MapSet.new([day1.sponsored.id, day2.sponsored.id]) == MapSet.new([a.id, c.id])
      # Same day, same sponsor.
      assert Finder.search(destination("gy"), "brooklyn", :any, today).sponsored.id ==
               day1.sponsored.id

      for result <- [day1, day2] do
        refute result.sponsored.id in Enum.map(result.shippers, & &1.id)
        expected = Enum.reject(["Alpha", "Beta", "Gamma"], &(&1 == result.sponsored.name))
        assert names(result.shippers) == expected
      end

      assert b.id in Enum.map(day1.shippers, & &1.id)
    end
  end

  describe "contact_target/2" do
    test "tel, wa.me and website links, or nil when missing" do
      company = %{phone: "(718) 555-0101", whatsapp_number: "+1 347 555 0102", website_url: nil}

      assert Finder.contact_target(company, :call) == "tel:+17185550101"
      assert Finder.contact_target(company, :whatsapp) == "https://wa.me/13475550102"
      assert Finder.contact_target(company, :website) == nil

      assert Finder.contact_target(%{company | whatsapp_number: "347 555 0102"}, :whatsapp) ==
               "https://wa.me/13475550102"

      assert Finder.contact_target(%{phone: nil, whatsapp_number: "12"}, :call) == nil
      assert Finder.contact_target(%{phone: nil, whatsapp_number: "12"}, :whatsapp) == nil
    end
  end

  test "christmas_season?/1 is inclusive of the configured window" do
    config = Application.fetch_env!(:shipper_directory, :finder)
    start = config[:christmas_window_start]
    finish = config[:christmas_window_end]

    assert Finder.christmas_season?(start)
    assert Finder.christmas_season?(finish)
    refute Finder.christmas_season?(Date.add(start, -1))
    refute Finder.christmas_season?(Date.add(finish, 1))
  end
end
