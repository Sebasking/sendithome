defmodule ShipperDirectory.Directory.Types.Service do
  @moduledoc "Services a shipper offers."
  use Ash.Type.Enum, values: [:barrel, :box, :vehicle, :container, :air, :pickup, :delivery]
end
