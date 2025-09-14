# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :neural_bridge,
  ecto_repos: [NeuralBridge.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :neural_bridge, NeuralBridgeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: NeuralBridgeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NeuralBridge.PubSub,
  live_view: [signing_salt: "UR2Wo2G8"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :neural_bridge, NeuralBridge.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban for background jobs
config :neural_bridge, Oban,
  repo: NeuralBridge.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron, crontab: [
      # Clean up old cache entries every hour
      {"0 * * * *", NeuralBridge.Workers.CacheCleanupWorker},
      # Generate training dataset daily at 2 AM
      {"0 2 * * *", NeuralBridge.Workers.TrainingDatasetWorker}
    ]}
  ],
  queues: [
    default: 10,
    embeddings: 5,
    training: 3,
    api_calls: 20
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
