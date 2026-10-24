defmodule ShipperDirectoryWeb.ScanController do
  @moduledoc """
  `/s/:code`, the short URL printed on new stickers. Logs the scan (with the
  raw code, even when it matches no sticker source) and redirects into the
  QR flow.
  """
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Analytics.{EventLog, ScanEvent}
  alias ShipperDirectoryWeb.{Bots, FlowParams}

  def show(conn, %{"code" => code} = params) do
    carry = FlowParams.carry(Map.put(params, "src", code))
    unless Bots.bot?(conn), do: EventLog.record(ScanEvent, FlowParams.scan_attrs(carry))

    redirect(conn, to: ~p"/start?#{FlowParams.query(carry)}")
  end
end
