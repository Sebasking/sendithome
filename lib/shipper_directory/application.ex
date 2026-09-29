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
      {Phoenix.PubSub, name: ShipperDirectory.PubSub},
      # Start a worker by calling: ShipperDirectory.Worker.start_link(arg)
      # {ShipperDirectory.Worker, arg},
      # Start to serve requests, typically the last entry
      ShipperDirectoryWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShipperDirectory.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShipperDirectoryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
