defmodule NeuralBridge.Schemas.CacheEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "cache_entries" do
    field :query_hash, :string
    field :query, :string
    field :response, :string
    field :metadata, :map, default: %{}
    field :hit_count, :integer, default: 0
    field :last_hit_at, :utc_datetime
    field :expires_at, :utc_datetime

    timestamps()
  end

  def changeset(cache_entry, attrs) do
    cache_entry
    |> cast(attrs, [
      :query_hash,
      :query,
      :response,
      :metadata,
      :hit_count,
      :last_hit_at,
      :expires_at
    ])
    |> validate_required([:query_hash, :query, :response])
    |> unique_constraint(:query_hash)
  end
end