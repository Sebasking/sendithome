defmodule Mix.Tasks.Directory.ImportSeed do
  @shortdoc "Imports the shipper seed CSV (idempotent)"
  @moduledoc """
  Imports the shipper seed CSV. Safe to rerun because rows are deduped.

      mix directory.import_seed                 # priv/seed/shipper_seed_list.csv
      mix directory.import_seed path/to/file.csv
  """
  use Mix.Task

  alias ShipperDirectory.Directory.Import.SeedCsv

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    path = List.first(args) || SeedCsv.default_path()
    %{created: created, updated: updated} = SeedCsv.import!(path)
    Mix.shell().info("Imported #{path}: #{created} created, #{updated} already present")
  end
end
