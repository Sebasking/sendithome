defmodule ShipperDirectoryWeb.Plugs.LegacyStickerScan do
  @moduledoc """
  The first sticker print points at `/?utm_source=sticker&utm_content=logo_a`
  (or `logo_b`). Logs the scan and sends the visitor into the QR flow at
  `/start` with the UTM params intact. Every other request passes through.
  """
  @behaviour Plug

  use ShipperDirectoryWeb, :verified_routes

  alias ShipperDirectory.Analytics.{EventLog, ScanEvent}
  alias ShipperDirectoryWeb.{Bots, FlowParams}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(
        %Plug.Conn{method: "GET", request_path: "/", query_params: %{"utm_source" => "sticker"}} =
          conn,
        _opts
      ) do
    carry = FlowParams.carry(conn.query_params)
    unless Bots.bot?(conn), do: EventLog.record(ScanEvent, FlowParams.scan_attrs(carry))

    conn
    |> Phoenix.Controller.redirect(to: ~p"/start?#{FlowParams.query(carry)}")
    |> Plug.Conn.halt()
  end

  def call(conn, _opts), do: conn
end
