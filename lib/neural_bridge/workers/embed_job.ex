defmodule NeuralBridge.Workers.EmbedJob do
  use Oban.Worker, queue: :embeddings, max_attempts: 3

  alias NeuralBridge.{Repo, LLM}
  alias NeuralBridge.Schemas.KnowledgeChunk
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"knowledge_chunk_id" => chunk_id}}) do
    case Repo.get(KnowledgeChunk, chunk_id) do
      nil ->
        Logger.error("Knowledge chunk not found: #{chunk_id}")
        {:error, :chunk_not_found}

      %KnowledgeChunk{embedding: nil} = chunk ->
        generate_and_store_embedding(chunk)

      %KnowledgeChunk{} = chunk ->
        Logger.info("Chunk #{chunk_id} already has embedding, skipping")
        :ok
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"batch_process" => true, "source_document" => source_document}}) do
    process_document_embeddings(source_document)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"reprocess_all" => true}}) do
    reprocess_all_embeddings()
  end

  def enqueue_chunk_embedding(chunk_id) do
    %{knowledge_chunk_id: chunk_id}
    |> new()
    |> Oban.insert()
  end

  def enqueue_document_batch(source_document) do
    %{batch_process: true, source_document: source_document}
    |> new()
    |> Oban.insert()
  end

  def enqueue_reprocess_all do
    %{reprocess_all: true}
    |> new()
    |> Oban.insert()
  end

  # Private functions

  defp generate_and_store_embedding(chunk) do
    Logger.info("Generating embedding for chunk: #{chunk.id}")

    case LLM.generate_embedding(chunk.content) do
      {:ok, embedding} ->
        chunk
        |> Ecto.Changeset.change(%{
          embedding: Jason.encode!(embedding),
          processed_at: DateTime.utc_now()
        })
        |> Repo.update()

        Logger.info("Successfully generated embedding for chunk: #{chunk.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate embedding for chunk #{chunk.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_document_embeddings(source_document) do
    import Ecto.Query

    chunks_without_embeddings =
      from(k in KnowledgeChunk,
        where: k.source_document == ^source_document and is_nil(k.embedding),
        order_by: [asc: k.chunk_index]
      )
      |> Repo.all()

    total_chunks = length(chunks_without_embeddings)
    Logger.info("Processing embeddings for #{total_chunks} chunks in document: #{source_document}")

    chunks_without_embeddings
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, 0}, fn {chunk, index}, {:ok, success_count} ->
      Logger.info("Processing chunk #{index}/#{total_chunks}")

      case generate_and_store_embedding(chunk) do
        :ok ->
          {:cont, {:ok, success_count + 1}}

        {:error, reason} ->
          Logger.error("Failed to process chunk #{index}: #{inspect(reason)}")
          # Continue processing other chunks even if one fails
          {:cont, {:ok, success_count}}
      end
    end)
    |> case do
      {:ok, success_count} ->
        Logger.info("Completed embedding generation for document #{source_document}: #{success_count}/#{total_chunks} successful")
        :ok

      error ->
        error
    end
  end

  defp reprocess_all_embeddings do
    import Ecto.Query

    all_chunks =
      from(k in KnowledgeChunk,
        order_by: [asc: k.source_document, asc: k.chunk_index]
      )
      |> Repo.all()

    total_chunks = length(all_chunks)
    Logger.info("Reprocessing embeddings for #{total_chunks} chunks")

    all_chunks
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, 0}, fn {chunk, index}, {:ok, success_count} ->
      if rem(index, 100) == 0 do
        Logger.info("Reprocessed #{index}/#{total_chunks} chunks")
      end

      case generate_and_store_embedding(chunk) do
        :ok ->
          {:cont, {:ok, success_count + 1}}

        {:error, reason} ->
          Logger.error("Failed to reprocess chunk #{index}: #{inspect(reason)}")
          {:cont, {:ok, success_count}}
      end
    end)
    |> case do
      {:ok, success_count} ->
        Logger.info("Completed reprocessing all embeddings: #{success_count}/#{total_chunks} successful")
        :ok

      error ->
        error
    end
  end
end