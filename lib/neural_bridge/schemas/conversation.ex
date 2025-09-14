defmodule NeuralBridge.Schemas.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :session_id, :string
    field :user_id, :string
    field :title, :string
    field :metadata, :map, default: %{}
    field :last_activity_at, :utc_datetime
    field :archived_at, :utc_datetime

    has_many :messages, NeuralBridge.Schemas.Message
    has_many :query_logs, NeuralBridge.Schemas.QueryLog

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:session_id, :user_id, :title, :metadata, :last_activity_at, :archived_at])
    |> validate_required([:session_id])
    |> unique_constraint(:session_id)
  end
end