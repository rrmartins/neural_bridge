defmodule NeuralBridge.Schemas.QueryLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "query_logs" do
    field :query, :string
    field :response, :string
    field :source, :string
    field :confidence_score, :float
    field :processing_time_ms, :integer
    field :api_b_called, :boolean, default: false
    field :feedback_score, :integer
    field :used_for_training, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :conversation, NeuralBridge.Schemas.Conversation

    timestamps()
  end

  def changeset(query_log, attrs) do
    query_log
    |> cast(attrs, [
      :query,
      :response,
      :source,
      :confidence_score,
      :processing_time_ms,
      :api_b_called,
      :feedback_score,
      :used_for_training,
      :metadata,
      :conversation_id
    ])
    |> validate_required([:query, :response, :source])
    |> validate_inclusion(:source, ["cache", "llm", "api_b", "rag"])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:feedback_score, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> foreign_key_constraint(:conversation_id)
  end
end