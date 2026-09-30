defmodule ShipperDirectory.Directory.Types.CompanyStatus do
  @moduledoc """
  Lifecycle of a company across the public directory and the prospect
  pipeline. `excluded` = triaged as not a Caribbean shipper; discovery never
  resurrects it.
  """
  use Ash.Type.Enum,
    values: [
      :discovered,
      :verified,
      :published,
      :prospect,
      :contacted,
      :customer,
      :declined,
      :do_not_contact,
      :excluded
    ]
end
