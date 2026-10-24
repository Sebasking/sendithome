defmodule ShipperDirectory.Analytics.EventLog do
  @moduledoc """
  Writes analytics events off the request path. Logging must never slow or
  break a request, so each write runs in a supervised task and a failure is
  logged and dropped. Tests write inline instead
  (`config :shipper_directory, :async_event_log, false`) so they can assert
  on the rows.
  """
  require Logger

  @doc "Records one event of `resource` (e.g. `Analytics.ScanEvent`)."
  def record(resource, attrs) when is_map(attrs), do: record_all(resource, [attrs])

  @doc "Records several events of one resource in a single insert."
  def record_all(_resource, []), do: :ok

  def record_all(resource, attrs_list) do
    run(fn -> Ash.bulk_create!(attrs_list, resource, :create) end)
  end

  defp run(fun) do
    if Application.get_env(:shipper_directory, :async_event_log, true) do
      _ = Task.Supervisor.start_child(ShipperDirectory.EventLogSupervisor, fn -> safely(fun) end)
      :ok
    else
      safely(fun)
    end
  end

  defp safely(fun) do
    fun.()
    :ok
  rescue
    error ->
      Logger.warning("Dropped analytics event: " <> Exception.message(error))
      :ok
  end
end
