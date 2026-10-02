defmodule ShipperDirectory.Directory.Types.LeadDeliveryStatus do
  @moduledoc "Where a shipper is with one quote request they received."
  use Ash.Type.Enum,
    values: [
      new: "New",
      contacted: "Contacted",
      booked: "Booked",
      lost: "Lost",
      disputed: "Disputed",
      credited: "Credited"
    ]
end
