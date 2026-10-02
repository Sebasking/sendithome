defmodule ShipperDirectory.Fixtures do
  @moduledoc "Test data builders."

  alias ShipperDirectory.Accounts.User
  alias ShipperDirectory.Directory

  def user(email) do
    User
    |> Ash.Changeset.for_create(:register_for_claim, %{email: email})
    |> Ash.create!(authorize?: false)
  end

  @doc "A published company in Brooklyn shipping to Guyana. Pass `owner: email` to claim it and opt in to leads."
  def company(attrs \\ %{}) do
    {owner_email, attrs} = Map.pop(attrs, :owner)

    company =
      Directory.create_company!(
        Map.merge(
          %{
            name: "Shipper #{System.unique_integer([:positive])}",
            city: "Brooklyn",
            state: "NY",
            destinations: ["Guyana"],
            website_url: "https://example.com",
            status: :published
          },
          attrs
        )
      )

    if owner_email do
      owner = user(owner_email)
      company |> Directory.assign_owner!(owner.id) |> Directory.set_accepts_leads!(true)
    else
      company
    end
  end

  def lead_params(attrs \\ %{}) do
    Map.merge(
      %{
        "name" => "Marcia",
        "phone" => "(347) 555-0101",
        "email" => "marcia@example.com",
        "origin_metro" => "brooklyn",
        "destination" => "guyana",
        "barrels" => "2",
        "boxes" => "1",
        "pickup_needed" => "true"
      },
      attrs
    )
  end
end
