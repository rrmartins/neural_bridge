defmodule NeuralBridge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NeuralBridgeWeb.Telemetry,
      NeuralBridge.Repo,
      {DNSCluster, query: Application.get_env(:neural_bridge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NeuralBridge.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: NeuralBridge.Finch},
      # Start Oban for background jobs
      {Oban, Application.fetch_env!(:neural_bridge, Oban)},
      # Start Cachex for caching
      {Cachex, name: :neural_bridge_cache, options: [limit: 10_000]},
      # Start ConversationServer registry
      {Registry, keys: :unique, name: NeuralBridge.ConversationRegistry},
      # Start ConversationServer supervisor
      {DynamicSupervisor, strategy: :one_for_one, name: NeuralBridge.ConversationSupervisor},
      # Start PromEx for observability (disabled temporarily)
      # NeuralBridge.PromEx,
      # Start to serve requests, typically the last entry
      NeuralBridgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NeuralBridge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NeuralBridgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
