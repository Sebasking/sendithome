defmodule ShipperDirectoryWeb.NotFoundError do
  @moduledoc "Raised for unknown or unpublished pages. Renders the 404 page."
  defexception message: "not found", plug_status: 404
end
