defmodule ShipperDirectory.Crm.Fit do
  @moduledoc """
  How good a prospect is for the website/booking-page offer (spec section
  9.3). Higher is better. Returns the score and its reasons, so the admin
  can see why a prospect ranks where it does.
  """

  alias ShipperDirectory.Directory.Company
  alias ShipperDirectory.Discovery.Metros

  @nyc Metros.nyc()

  def score(%Company{} = c) do
    [
      {c.google_has_website == false, 3, "No website on Google Maps"},
      {c.presence_status == :dead_site, 2, "Website is dead"},
      {c.presence_status == :social_only, 2, "Social media only"},
      {not is_nil(c.fmc_license_no), 2, "FMC licensed (established)"},
      {not is_nil(c.normalized_phone), 2, "Has a phone number"},
      {Enum.any?(c.metro_slugs, &(&1 in @nyc)), 1, "NYC (launch metro)"},
      {"seed_csv" in c.source, 1, "On the seed list"}
    ]
    |> Enum.filter(&elem(&1, 0))
    |> Enum.reduce({0, []}, fn {_, points, reason}, {total, reasons} ->
      {total + points, reasons ++ ["+#{points} #{reason}"]}
    end)
  end
end
