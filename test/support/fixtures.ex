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

  @doc "A published, phone-verified company (shown in the QR flow). Brooklyn to Guyana by default."
  def verified_company(attrs \\ %{}) do
    attrs |> company() |> Directory.set_company_verified!(true)
  end

  @doc "Sets the QR flow's Christmas window so today is inside it (or not). Restored after the test."
  def put_christmas_season(in_season?) do
    original = Application.fetch_env!(:shipper_directory, :finder)
    today = Date.utc_today()

    {start, finish} =
      if in_season?,
        do: {Date.add(today, -10), Date.add(today, 10)},
        else: {Date.add(today, 10), Date.add(today, 20)}

    Application.put_env(
      :shipper_directory,
      :finder,
      Keyword.merge(original, christmas_window_start: start, christmas_window_end: finish)
    )

    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:shipper_directory, :finder, original) end)
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
