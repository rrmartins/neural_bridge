defmodule NeuralBridge.Repo do
  use Ecto.Repo,
    otp_app: :neural_bridge,
    adapter: Ecto.Adapters.Postgres
end
