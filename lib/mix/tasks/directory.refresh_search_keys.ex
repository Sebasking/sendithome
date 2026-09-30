defmodule Mix.Tasks.Directory.RefreshSearchKeys do
  @shortdoc "Recomputes metro/destination slugs and match keys for every company"
  @moduledoc """
  Re-saves every company through the `:update` action so derived keys
  (metro_slugs, destination_slugs, name_key, name_core) are current. Run it
  after changing `Metros` aliases or `Destinations`.
  """
  use Mix.Task

  alias ShipperDirectory.Directory

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    companies = Directory.list_companies!()
    Enum.each(companies, &Directory.update_company!(&1, %{}))
    Mix.shell().info("Refreshed #{length(companies)} companies")
  end
end
