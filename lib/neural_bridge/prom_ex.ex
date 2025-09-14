defmodule NeuralBridge.PromEx do
  use PromEx, otp_app: :neural_bridge

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # Built-in plugins
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: NeuralBridgeWeb.Router, endpoint: NeuralBridgeWeb.Endpoint},
      Plugins.Ecto,
      Plugins.Oban,

      # Custom plugin for LLM proxy metrics
      NeuralBridge.PromEx.LLMProxyPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      # Built-in dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"},

      # Custom dashboard
      {:neural_bridge, "llm_proxy.json"}
    ]
  end
end