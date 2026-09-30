defmodule ShipperDirectory.Workers.PresenceRecheckScheduler do
  @moduledoc """
  Daily cron. Queues a presence check for every company not checked in the
  last 30 days (or never checked). A published company whose site has gone
  dead gets demoted to a prospect automatically.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Workers.PresenceCheckWorker

  @recheck_after_days 30

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -@recheck_after_days, :day)

    cutoff
    |> Directory.companies_due_for_check!()
    |> Enum.map(&PresenceCheckWorker.new(%{company_id: &1.id}))
    |> Oban.insert_all()

    :ok
  end
end
