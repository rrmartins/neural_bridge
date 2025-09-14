defmodule NeuralBridge.Schemas.KnowledgeChunk do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "knowledge_chunks" do
    field :source_document, :string
    field :chunk_index, :integer
    field :content, :string
    field :embedding, :string  # JSON encoded embedding vector (will be vector type when pgvector is available)
    field :metadata, :map, default: %{}
    field :processed_at, :utc_datetime

    timestamps()
  end

  def changeset(knowledge_chunk, attrs) do
    knowledge_chunk
    |> cast(attrs, [
      :source_document,
      :chunk_index,
      :content,
      :embedding,
      :metadata,
      :processed_at
    ])
    |> validate_required([:content])
    |> validate_number(:chunk_index, greater_than_or_equal_to: 0)
  end
end