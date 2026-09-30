defmodule ShipperDirectory.Directory.Types.PresenceStatus do
  @moduledoc """
  Result of the presence check. `nil` on a company means it has not been
  checked yet.
  """
  use Ash.Type.Enum, values: [:listed, :social_only, :dead_site, :none, :needs_review]
end
