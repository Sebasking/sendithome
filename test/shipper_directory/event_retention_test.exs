defmodule ShipperDirectory.EventRetentionTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Analytics.{EventLog, ScanEvent}
  alias ShipperDirectory.Workers.EventRetentionWorker

  test "deletes events older than the cutoff and keeps the rest" do
    :ok = EventLog.record(ScanEvent, %{source_code: "old"})
    :ok = EventLog.record(ScanEvent, %{source_code: "new"})

    Repo.query!(
      "UPDATE scan_events SET inserted_at = now() - interval '25 months' WHERE source_code = 'old'"
    )

    assert :ok = EventRetentionWorker.perform(%Oban.Job{})
    assert [%{source_code: "new"}] = Ash.read!(ScanEvent)
  end

  @tag :capture_log
  test "a failed write is dropped, not raised" do
    assert :ok = EventLog.record(ScanEvent, %{source_code: 123})
    assert Ash.read!(ScanEvent) == []
  end
end
