defmodule ShipperDirectory.Directory.LocationTypesTest do
  use ExUnit.Case, async: true

  alias ShipperDirectory.Directory.Types.{DestinationSlug, Metro}

  test "valid slugs cast, ignoring case" do
    assert Ash.Type.cast_input(Metro, "Queens", []) == {:ok, "queens"}
    assert Ash.Type.cast_input(DestinationSlug, "JAMAICA", []) == {:ok, "jamaica"}
    assert Ash.Type.cast_input(Metro, nil, []) == {:ok, nil}
  end

  test "unknown slugs are rejected with the valid ones listed" do
    assert {:error, message: message} = Ash.Type.cast_input(Metro, "atlantis", [])
    assert message =~ "must be one of: brooklyn, queens"

    assert {:error, message: message} = Ash.Type.cast_input(DestinationSlug, "mars", [])
    assert message =~ "must be one of: jamaica, guyana"

    refute Metro.match?("atlantis")
  end

  test "the message reaches the changeset error" do
    changeset =
      Ash.Changeset.for_create(ShipperDirectory.Directory.Placement, :create, %{metro: "atlantis"})

    assert Enum.any?(changeset.errors, &(&1.field == :metro and &1.message =~ "must be one of"))
  end
end
