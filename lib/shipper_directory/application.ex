defmodule ShipperDirectory.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShipperDirectoryWeb.Telemetry,
      ShipperDirectory.Repo,
      {DNSCluster, query: Application.get_env(:shipper_directory, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:shipper_directory, Oban)},
      # Holds dev/test claim codes when phone codes are logged instead of sent.
      phone_sender_log(),
      {Phoenix.PubSub, name: ShipperDirectory.PubSub},
      # Start a worker by calling: ShipperDirectory.Worker.start_link(arg)
      # {ShipperDirectory.Worker, arg},
      # Start to serve requests, typically the last entry
      ShipperDirectoryWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :shipper_directory]}
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShipperDirectory.Supervisor]
    Supervisor.start_link(Enum.reject(children, &is_nil/1), opts)
  end

  defp phone_sender_log do
    log = ShipperDirectory.Claims.PhoneSender.Log
    if Application.get_env(:shipper_directory, :phone_sender) == log, do: log
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShipperDirectoryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
