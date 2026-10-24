defmodule ShipperDirectoryWeb.Bots do
  @moduledoc """
  Known crawlers and link previewers, so they aren't counted as scans or
  leads. The user agent is checked in memory and never stored.
  """

  @pattern ~r/bot\b|bot\/|crawl|spider|slurp|facebookexternalhit|preview|whatsapp|telegram|discord|slack|embedly|pinterest|vkshare|lighthouse|headless|curl|wget|python-requests|go-http-client/i

  def bot?(%Plug.Conn{} = conn),
    do: conn |> Plug.Conn.get_req_header("user-agent") |> List.first() |> bot?()

  def bot?(user_agent) when is_binary(user_agent), do: Regex.match?(@pattern, user_agent)
  def bot?(_user_agent), do: false
end
