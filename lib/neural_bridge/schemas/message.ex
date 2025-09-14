defmodule NeuralBridge.Schemas.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "messages" do
    field :role, :string
    field :content, :string
    field :metadata, :map, default: %{}
    field :source, :string
    field :confidence_score, :float
    field :processing_time_ms, :integer
    field :token_count, :integer

    belongs_to :conversation, NeuralBridge.Schemas.Conversation

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :role,
      :content,
      :metadata,
      :source,
      :confidence_score,
      :processing_time_ms,
      :token_count,
      :conversation_id
    ])
    |> validate_required([:role, :content, :conversation_id])
    |> validate_inclusion(:role, ["user", "assistant", "system"])
    |> foreign_key_constraint(:conversation_id)
  end
end