defmodule Mix.Tasks.Directory.ImportFmc do
  @shortdoc "Imports the FMC licensed OTI list (cross-reference + discovery)"
  @moduledoc """
  Imports the FMC licensed OTI list. Idempotent.

      mix directory.import_fmc                        # download, NYC boroughs
      mix directory.import_fmc --metros brooklyn,queens
      mix directory.import_fmc --metros all
      mix directory.import_fmc --file "OTI List.xlsx"  # use a saved download

  Metros: #{Enum.join(ShipperDirectory.Discovery.Metros.slugs(), ", ")}
  """
  use Mix.Task

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.{Fmc, Metros}

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [metros: :string, file: :string])

    metros =
      case opts[:metros] do
        nil -> Metros.nyc()
        "all" -> Metros.slugs()
        list -> String.split(list, ",", trim: true)
      end

    unknown = metros -- Metros.slugs()
    if unknown != [], do: Mix.raise("Unknown metros: #{Enum.join(unknown, ", ")}")

    run = Directory.start_discovery_run!("fmc", %{params: %{"metros" => metros}})

    records =
      case opts[:file] do
        nil -> Fmc.download!() |> Fmc.parse!()
        path -> Fmc.parse!(path, :path)
      end

    stats = Fmc.import!(records, metros: metros)
    Directory.finish_discovery_run!(run, %{stats: stats})
    Mix.shell().info("FMC import: #{inspect(stats)}")
  end
end
