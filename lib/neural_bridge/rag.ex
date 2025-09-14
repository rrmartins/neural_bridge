defmodule NeuralBridge.RAG do
  require Logger

  alias NeuralBridge.Repo
  alias NeuralBridge.Schemas.KnowledgeChunk
  alias NeuralBridge.LLM

  @chunk_size 1000
  @chunk_overlap 200
  @similarity_threshold 0.7

  def ingest_document(content, source_document, metadata \\ %{}) do
    chunks = chunk_text(content)

    chunks
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      Task.async(fn ->
        case LLM.generate_embedding(chunk) do
          {:ok, embedding} ->
            %KnowledgeChunk{
              id: UUID.uuid4(),
              source_document: source_document,
              chunk_index: index,
              content: chunk,
              embedding: Jason.encode!(embedding),
              metadata: Map.merge(metadata, %{chunk_size: String.length(chunk)}),
              processed_at: DateTime.utc_now()
            }
            |> Repo.insert()

          {:error, reason} ->
            Logger.error("Failed to generate embedding for chunk #{index}: #{inspect(reason)}")
            {:error, reason}
        end
      end)
    end)
    |> Task.await_many(30_000)
    |> Enum.filter(fn
      {:ok, _} -> true
      _ -> false
    end)
    |> length()
    |> then(fn successful_chunks ->
      Logger.info(
        "Ingested #{successful_chunks}/#{length(chunks)} chunks for document: #{source_document}"
      )

      {:ok, successful_chunks}
    end)
  end

  def retrieve(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    similarity_threshold = Keyword.get(opts, :similarity_threshold, @similarity_threshold)

    start_time = System.monotonic_time(:millisecond)

    with {:ok, query_embedding} <- LLM.generate_embedding(query),
         chunks <- find_similar_chunks(query_embedding, limit, similarity_threshold) do
      processing_time = System.monotonic_time(:millisecond) - start_time

      :telemetry.execute(
        [:neural_bridge, :rag, :query],
        %{},
        %{status: "success"}
      )

      :telemetry.execute(
        [:neural_bridge, :rag, :retrieval],
        %{processing_time: processing_time},
        %{}
      )

      {:ok, chunks}
    else
      {:error, reason} ->
        :telemetry.execute(
          [:neural_bridge, :rag, :query],
          %{},
          %{status: "error"}
        )

        Logger.error("RAG retrieval failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def search_by_document(source_document, query \\ nil, opts \\ []) do
    import Ecto.Query

    base_query =
      from(k in KnowledgeChunk,
        where: k.source_document == ^source_document,
        order_by: [asc: k.chunk_index]
      )

    query =
      if query do
        # If a search query is provided, filter by content similarity
        from(k in base_query,
          where: ilike(k.content, ^"%#{query}%")
        )
      else
        base_query
      end

    limit = Keyword.get(opts, :limit, 50)

    query
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(&prepare_chunk_for_response/1)
  end

  def list_documents(opts \\ []) do
    import Ecto.Query

    limit = Keyword.get(opts, :limit, 100)

    from(k in KnowledgeChunk,
      select: %{
        source_document: k.source_document,
        chunk_count: count(k.id),
        last_processed: max(k.processed_at),
        total_content_length: sum(fragment("length(?)", k.content))
      },
      group_by: k.source_document,
      order_by: [desc: max(k.processed_at)],
      limit: ^limit
    )
    |> Repo.all()
  end

  def delete_document(source_document) do
    import Ecto.Query

    from(k in KnowledgeChunk, where: k.source_document == ^source_document)
    |> Repo.delete_all()
  end

  def get_document_stats(source_document) do
    import Ecto.Query

    stats =
      from(k in KnowledgeChunk,
        where: k.source_document == ^source_document,
        select: %{
          chunk_count: count(k.id),
          total_content_length: sum(fragment("length(?)", k.content)),
          avg_chunk_length: avg(fragment("length(?)", k.content)),
          first_processed: min(k.processed_at),
          last_processed: max(k.processed_at)
        }
      )
      |> Repo.one()

    case stats do
      nil -> {:error, :document_not_found}
      stats -> {:ok, stats}
    end
  end

  def reprocess_document(source_document) do
    import Ecto.Query

    # Get all chunks for the document
    chunks =
      from(k in KnowledgeChunk,
        where: k.source_document == ^source_document,
        order_by: [asc: k.chunk_index]
      )
      |> Repo.all()

    case chunks do
      [] ->
        {:error, :document_not_found}

      chunks ->
        # Reconstruct the original document content
        content =
          chunks
          |> Enum.map(& &1.content)
          |> Enum.join(" ")

        # Delete existing chunks
        delete_document(source_document)

        # Re-ingest with updated processing
        metadata = %{reprocessed_at: DateTime.utc_now()}
        ingest_document(content, source_document, metadata)
    end
  end

  # Private functions

  defp chunk_text(text) do
    # Simple sentence-based chunking with overlap
    sentences = String.split(text, ~r/[.!?]+\s*/, trim: true)

    sentences
    |> Enum.chunk_every(10, 5)  # 10 sentences per chunk, 5 sentence overlap
    |> Enum.map(&Enum.join(&1, ". "))
    |> Enum.filter(&(String.length(&1) > 50))  # Filter out very short chunks
  end

  defp find_similar_chunks(query_embedding, limit, similarity_threshold) do
    # For now, we'll use a simple content-based search since pgvector is not available
    # In production, this would use cosine similarity with pgvector
    import Ecto.Query

    # Fallback to content-based search
    from(k in KnowledgeChunk,
      limit: ^limit,
      order_by: [desc: k.processed_at]
    )
    |> Repo.all()
    |> Enum.map(&prepare_chunk_for_response/1)
    |> Enum.take(limit)
  end

  # TODO: Implement when pgvector is available
  defp cosine_similarity_search(query_embedding, limit, similarity_threshold) do
    # This would use pgvector's cosine similarity
    # SELECT content, metadata, 1 - (embedding <=> ?) as similarity
    # FROM knowledge_chunks
    # WHERE 1 - (embedding <=> ?) > ?
    # ORDER BY embedding <=> ?
    # LIMIT ?
    []
  end

  defp prepare_chunk_for_response(chunk) do
    %{
      content: chunk.content,
      source_document: chunk.source_document,
      chunk_index: chunk.chunk_index,
      metadata: chunk.metadata,
      processed_at: chunk.processed_at
    }
  end

  # Embedding similarity calculation (for when pgvector is not available)
  defp calculate_cosine_similarity(embedding1, embedding2) when is_list(embedding1) and is_list(embedding2) do
    dot_product = Enum.zip(embedding1, embedding2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()

    norm1 = :math.sqrt(Enum.map(embedding1, &(&1 * &1)) |> Enum.sum())
    norm2 = :math.sqrt(Enum.map(embedding2, &(&1 * &1)) |> Enum.sum())

    if norm1 == 0 or norm2 == 0 do
      0
    else
      dot_product / (norm1 * norm2)
    end
  end

  defp calculate_cosine_similarity(_, _), do: 0
end