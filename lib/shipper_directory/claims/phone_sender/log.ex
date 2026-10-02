defmodule ShipperDirectory.Claims.PhoneSender.Log do
  @moduledoc """
  Dev/test phone sender. Logs the code, and keeps the last code per
  number so tests (and you, in dev) can read it with `last_code/1`.
  Started in the supervision tree only when it's the configured adapter.
  """
  @behaviour ShipperDirectory.Claims.PhoneSender

  use Agent

  require Logger

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  @impl ShipperDirectory.Claims.PhoneSender
  def deliver(method, to, code) do
    Agent.update(__MODULE__, &Map.put(&1, to, code))
    Logger.info("[claim code] #{method} to #{to}: #{code}")
    :ok
  end

  def last_code(to), do: Agent.get(__MODULE__, &Map.get(&1, to))
end
