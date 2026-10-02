defmodule ShipperDirectory.PlacementsTest do
  use ShipperDirectory.DataCase, async: true

  import ShipperDirectory.Fixtures

  alias ShipperDirectory.{Directory, Placements}

  defp place(company, attrs \\ %{}) do
    today = Date.utc_today()

    Directory.create_placement(
      Map.merge(
        %{
          company_id: company.id,
          metro: "brooklyn",
          destination: "guyana",
          starts_on: today,
          ends_on: Date.add(today, 30)
        },
        attrs
      )
    )
  end

  test "active sponsors for a route, excluded from the organic list" do
    a = company(%{name: "Alpha"})
    b = company(%{name: "Beta"})
    {:ok, _} = place(b)

    assert {[%{id: id}], organic} = Placements.split([a, b], "brooklyn", "guyana")
    assert id == b.id
    assert Enum.map(organic, & &1.id) == [a.id]
    assert Placements.sponsored("queens", "guyana") == []
  end

  test "date window and unpublished companies" do
    a = company(%{name: "Alpha"})
    today = Date.utc_today()
    {:ok, _} = place(a, %{starts_on: Date.add(today, 1), ends_on: Date.add(today, 10)})
    assert Placements.sponsored("brooklyn", "guyana") == []

    b = company(%{name: "Beta"})
    {:ok, _} = place(b)
    Directory.set_company_status!(b, :prospect)
    assert Placements.sponsored("brooklyn", "guyana") == []
  end

  test "metro-wide placements show only on routes the company serves" do
    a = company(%{name: "Alpha", destinations: ["Guyana"]})
    {:ok, _} = place(a, %{destination: nil})
    assert [_] = Placements.sponsored("brooklyn", "guyana")
    assert Placements.sponsored("brooklyn", "jamaica") == []
    assert [_] = Placements.sponsored("brooklyn", nil)
  end

  test "slots hold at most 2 overlapping placements; a company can't double up" do
    [a, b, c] = for n <- ~w(A B C), do: company(%{name: n})
    {:ok, _} = place(a)
    assert {:error, error} = place(a)
    assert Exception.message(error) =~ "already has a placement"

    {:ok, _} = place(b, %{destination: nil})
    assert {:error, error} = place(c)
    assert Exception.message(error) =~ "slot is full"

    # A non-overlapping window is fine.
    today = Date.utc_today()
    assert {:ok, _} = place(c, %{starts_on: Date.add(today, 31), ends_on: Date.add(today, 60)})
  end

  test "end date before start is invalid" do
    today = Date.utc_today()
    assert {:error, _} = place(company(), %{starts_on: today, ends_on: Date.add(today, -1)})
  end
end
