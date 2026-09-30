defmodule ShipperDirectory.Workers.FmcImportWorker do
  @moduledoc """
  Downloads the FMC OTI list, cross-references license numbers, and
  discovers licensees in the given metros (default: NYC). Weekly via cron.
  Queues Google lookups for newly confirmed companies.
  """
  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 600]

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.{Fmc, Metros}
  alias ShipperDirectory.Workers.GoogleLookupWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    metros = Map.get(args, "metros", Metros.nyc())
    run = Directory.start_discovery_run!("fmc", %{params: %{"metros" => metros}})

    try do
      stats = Fmc.download!() |> Fmc.parse!() |> Fmc.import!(metros: metros)
      GoogleLookupWorker.enqueue_pending()
      Directory.finish_discovery_run!(run, %{stats: stats})
      :ok
    rescue
      e ->
        Directory.fail_discovery_run!(run, Exception.message(e))
        reraise e, __STACKTRACE__
    end
  end
end
