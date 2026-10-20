defmodule Mix.Tasks.Directory.ImportScored do
  @shortdoc "Imports a scored FMC OTI list CSV, keeping tier B and above"
  @moduledoc """
  Imports a scored copy of the FMC OTI list: the usual OTI columns plus a
  `tier` column ("A_strong", "B_likely_area", "C_weak", "D_none"). Keeps US
  licensees at `--min-tier` or better (default B). Idempotent.

      mix directory.import_scored ~/Downloads/shipper_list_scored.csv
      mix directory.import_scored shipper_list_scored.csv --min-tier A
  """
  use Mix.Task

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.Fmc

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, paths, _} = OptionParser.parse(args, strict: [min_tier: :string])

    path =
      case paths do
        [path] -> Path.expand(path)
        _ -> Mix.raise("Usage: mix directory.import_scored path/to/scored.csv [--min-tier B]")
      end

    min_tier = opts[:min_tier] || "B"

    run =
      Directory.start_discovery_run!("fmc_scored", %{
        params: %{"file" => Path.basename(path), "min_tier" => min_tier}
      })

    stats =
      path
      |> File.read!()
      |> String.trim_leading("\uFEFF")
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      |> Fmc.parse_rows()
      |> Fmc.import_scored!(min_tier: min_tier)

    Directory.finish_discovery_run!(run, %{stats: stats})
    Mix.shell().info("Scored import: #{inspect(stats)}")
  end
end
