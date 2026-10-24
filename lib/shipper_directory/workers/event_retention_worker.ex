defmodule ShipperDirectory.Workers.EventRetentionWorker do
  @moduledoc """
  Nightly: deletes analytics events older than `:event_retention_months`
  (default 24). Any sponsor-report aggregates must be computed before rows
  age out.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Ash.Query

  alias ShipperDirectory.Analytics

  @impl Oban.Worker
  def perform(_job) do
    months = Application.get_env(:shipper_directory, :event_retention_months, 24)
    expire_before(DateTime.shift(DateTime.utc_now(), month: -months))
  end

  @doc "Deletes every event inserted before `cutoff`."
  def expire_before(cutoff) do
    for resource <- Analytics.event_resources() do
      resource
      |> Ash.Query.filter(inserted_at < ^cutoff)
      |> Ash.bulk_destroy!(:expire, %{}, strategy: [:atomic, :stream])
    end

    :ok
  end
end
