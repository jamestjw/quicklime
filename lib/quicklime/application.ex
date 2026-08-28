defmodule Quicklime.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QuicklimeWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:quicklime, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Quicklime.PubSub},
      Quicklime.RegionalGame,
      # Start to serve requests, typically the last entry
      QuicklimeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quicklime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuicklimeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
