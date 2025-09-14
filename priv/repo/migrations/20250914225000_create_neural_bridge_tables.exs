defmodule NeuralBridge.Repo.Migrations.CreateNeuralBridgeTables do
  use Ecto.Migration

  def change do
    # Conversations table for session management
    create table(:conversations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_id, :string, null: false
      add :user_id, :string
      add :title, :string
      add :metadata, :map, default: %{}
      add :last_activity_at, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps()
    end

    create index(:conversations, [:session_id])
    create index(:conversations, [:user_id])
    create index(:conversations, [:last_activity_at])

    # Messages table for conversation history
    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all), null: false
      add :role, :string, null: false  # "user", "assistant", "system"
      add :content, :text, null: false
      add :metadata, :map, default: %{}
      add :source, :string  # "cache", "llm", "api_b", "rag"
      add :confidence_score, :float
      add :processing_time_ms, :integer
      add :token_count, :integer

      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:role])
    create index(:messages, [:source])
    create index(:messages, [:confidence_score])

    # Knowledge base for RAG
    create table(:knowledge_chunks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :source_document, :string
      add :chunk_index, :integer
      add :content, :text, null: false
      add :embedding, :text  # Will be vector(1536) when pgvector is available
      add :metadata, :map, default: %{}
      add :processed_at, :utc_datetime

      timestamps()
    end

    create index(:knowledge_chunks, [:source_document])
    create index(:knowledge_chunks, [:chunk_index])

    # Query logs for training data
    create table(:query_logs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :conversation_id, references(:conversations, type: :uuid, on_delete: :nilify_all)
      add :query, :text, null: false
      add :response, :text, null: false
      add :source, :string, null: false  # "cache", "llm", "api_b", "rag"
      add :confidence_score, :float
      add :processing_time_ms, :integer
      add :api_b_called, :boolean, default: false
      add :feedback_score, :integer  # User feedback rating
      add :used_for_training, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:query_logs, [:source])
    create index(:query_logs, [:confidence_score])
    create index(:query_logs, [:api_b_called])
    create index(:query_logs, [:used_for_training])
    create index(:query_logs, [:feedback_score])

    # Cache entries
    create table(:cache_entries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :query_hash, :string, null: false
      add :query, :text, null: false
      add :response, :text, null: false
      add :metadata, :map, default: %{}
      add :hit_count, :integer, default: 0
      add :last_hit_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:cache_entries, [:query_hash])
    create index(:cache_entries, [:expires_at])
    create index(:cache_entries, [:hit_count])

    # Training jobs tracking
    create table(:training_jobs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :status, :string, null: false  # "pending", "running", "completed", "failed"
      add :job_type, :string, null: false  # "embedding", "fine_tune", "distillation"
      add :dataset_size, :integer
      add :progress_percentage, :float, default: 0.0
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :error_message, :text
      add :config, :map, default: %{}
      add :results, :map, default: %{}

      timestamps()
    end

    create index(:training_jobs, [:status])
    create index(:training_jobs, [:job_type])
    create index(:training_jobs, [:started_at])
  end
end
