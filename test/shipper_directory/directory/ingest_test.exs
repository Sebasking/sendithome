defmodule ShipperDirectory.Directory.IngestTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Ingest, Merge}

  defp ingest(attrs, id), do: Ingest.ingest!(attrs, "test", id, %{})

  test "flags a same-name company as a possible duplicate" do
    {:created, seed} = ingest(%{name: "Dennis Shipping"}, "1")

    {:created, fmc} =
      ingest(
        %{
          name: "DENNIS SHIPPING CO., INC.",
          state: "NY",
          phone: "718-451-3617",
          address: "1 Utica Ave"
        },
        "2"
      )

    assert fmc.possible_duplicate_of_id == seed.id
  end

  test "doesn't flag two fully specified businesses that share a name word" do
    ingest(
      %{name: "Compass Shipping", state: "NY", phone: "718-773-5430", address: "1 A St"},
      "1"
    )

    {:created, other} =
      ingest(
        %{name: "Compass Forwarding Co.", state: "NY", phone: "718-555-0000", address: "9 B St"},
        "2"
      )

    assert other.possible_duplicate_of_id == nil
  end

  test "doesn't flag across states" do
    ingest(%{name: "Safari Shipping", state: "FL"}, "1")
    {:created, other} = ingest(%{name: "Safari Shipping Inc", state: "NY"}, "2")
    assert other.possible_duplicate_of_id == nil
  end

  test "address abbreviations match for dedupe" do
    {:created, a} =
      ingest(
        %{name: "Barrel-It", address: "35 Rogers Avenue", city: "Brooklyn", state: "NY"},
        "1"
      )

    {:updated, b} =
      ingest(%{name: "BARREL-IT", address: "35 ROGERS AVE", city: "BROOKLYN", state: "NY"}, "2")

    assert a.id == b.id
  end

  test "merge moves sightings, fills blanks, and deletes the duplicate" do
    {:created, keep} = ingest(%{name: "Dennis Shipping", destinations: ["Jamaica"]}, "1")

    {:created, dup} =
      ingest(
        %{
          name: "Dennis Shipping Co., Inc.",
          address: "1124 Utica Ave",
          phone: "718-451-3617",
          fmc_license_no: "015070",
          destinations: ["Guyana"]
        },
        "2"
      )

    assert dup.possible_duplicate_of_id == keep.id
    kept = Merge.merge!(keep, dup)

    assert %{
             phone: "718-451-3617",
             fmc_license_no: "015070",
             address: "1124 Utica Ave",
             destinations: ["Jamaica", "Guyana"],
             possible_duplicate_of_id: nil
           } = kept

    assert {:error, _} = Directory.get_company(dup.id)
    assert kept |> Ash.load!(:sightings) |> Map.get(:sightings) |> length() == 2

    # A later sighting from the duplicate's source record lands on the kept company.
    assert {:updated, %{id: id}} = ingest(%{name: "Dennis Shipping Co., Inc."}, "2")
    assert id == keep.id
  end
end
