defmodule NeuralBridge.Cache do
  require Logger

  alias NeuralBridge.Repo
  alias NeuralBridge.Schemas.CacheEntry

  @cache_name :neural_bridge_cache
  @default_ttl :timer.hours(24)

  def get(query, context \\ "") do
    query_hash = generate_hash(query, context)

    # First check in-memory cache (Cachex)
    case Cachex.get(@cache_name, query_hash) do
      {:ok, nil} ->
        # Check persistent cache (database)
        check_persistent_cache(query_hash)

      {:ok, response} ->
        # Update hit metrics
        :telemetry.execute([:neural_bridge, :cache, :accessed], %{}, %{result: "memory_hit"})
        {:ok, response}

      {:error, reason} ->
        Logger.warning("Cache error: #{inspect(reason)}")
        {:error, :cache_error}
    end
  end

  def put(query, context \\ "", response, opts \\ []) do
    query_hash = generate_hash(query, context)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = DateTime.utc_now() |> DateTime.add(ttl, :millisecond)

    # Store in memory cache
    case Cachex.put(@cache_name, query_hash, response, ttl: ttl) do
      {:ok, true} ->
        # Also store in persistent cache for durability
        Task.start(fn ->
          store_persistent_cache(query_hash, query, response, expires_at, opts)
        end)

        :ok

      {:error, reason} ->
        Logger.warning("Failed to cache response: #{inspect(reason)}")
        {:error, :cache_error}
    end
  end

  def delete(query, context \\ "") do
    query_hash = generate_hash(query, context)

    # Remove from memory cache
    Cachex.del(@cache_name, query_hash)

    # Remove from persistent cache
    Task.start(fn ->
      delete_persistent_cache(query_hash)
    end)

    :ok
  end

  def invalidate_pattern(pattern) do
    # For more advanced pattern matching, could use Cachex.stream
    # For now, we'll implement a simple prefix-based invalidation
    case Cachex.stream(@cache_name) do
      {:ok, stream} ->
        stream
        |> Stream.filter(fn {key, _value} -> String.contains?(key, pattern) end)
        |> Stream.each(fn {key, _value} -> Cachex.del(@cache_name, key) end)
        |> Stream.run()

      {:error, reason} ->
        Logger.warning("Failed to invalidate cache pattern: #{inspect(reason)}")
        {:error, :cache_error}
    end
  end

  def clear_all do
    Cachex.clear(@cache_name)
    Task.start(fn -> clear_persistent_cache() end)
    :ok
  end

  def size do
    case Cachex.size(@cache_name) do
      {:ok, size} -> size
      {:error, _} -> 0
    end
  end

  def stats do
    case Cachex.stats(@cache_name) do
      {:ok, stats} ->
        # Add persistent cache stats
        persistent_stats = get_persistent_cache_stats()
        Map.merge(stats, persistent_stats)

      {:error, reason} ->
        Logger.warning("Failed to get cache stats: #{inspect(reason)}")
        %{}
    end
  end

  def cleanup_expired do
    # Cachex handles memory cache TTL automatically
    # Clean up expired persistent cache entries
    Task.start(fn ->
      cleanup_expired_persistent_cache()
    end)

    :ok
  end

  # Private functions

  defp generate_hash(query, context) do
    content = query <> "|" <> context
    :crypto.hash(:sha256, content) |> Base.encode16() |> String.downcase()
  end

  defp check_persistent_cache(query_hash) do
    case Repo.get_by(CacheEntry, query_hash: query_hash) do
      nil ->
        {:error, :not_found}

      %CacheEntry{expires_at: expires_at} = entry ->
        now = DateTime.utc_now()
        if DateTime.compare(expires_at, now) == :lt do
          # Expired entry, delete it
          Repo.delete(entry)
          {:error, :not_found}
        else
          # Update hit count and last hit time
          entry
          |> Ecto.Changeset.change(%{
            hit_count: entry.hit_count + 1,
            last_hit_at: DateTime.utc_now()
          })
          |> Repo.update()

          # Also store in memory cache for faster future access
          Cachex.put(@cache_name, query_hash, entry.response)

          :telemetry.execute([:neural_bridge, :cache, :accessed], %{}, %{result: "persistent_hit"})
          {:ok, entry.response}
        end
    end
  end

  defp store_persistent_cache(query_hash, query, response, expires_at, opts) do
    metadata = Keyword.get(opts, :metadata, %{})

    %CacheEntry{
      id: UUID.uuid4(),
      query_hash: query_hash,
      query: query,
      response: response,
      metadata: metadata,
      expires_at: expires_at,
      hit_count: 0
    }
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:query_hash])
  end

  defp delete_persistent_cache(query_hash) do
    case Repo.get_by(CacheEntry, query_hash: query_hash) do
      nil -> :ok
      entry -> Repo.delete(entry)
    end
  end

  defp clear_persistent_cache do
    Repo.delete_all(CacheEntry)
  end

  defp cleanup_expired_persistent_cache do
    import Ecto.Query

    from(c in CacheEntry, where: c.expires_at < ^DateTime.utc_now())
    |> Repo.delete_all()
  end

  defp get_persistent_cache_stats do
    import Ecto.Query

    total_entries = Repo.aggregate(CacheEntry, :count)

    expired_entries =
      from(c in CacheEntry, where: c.expires_at < ^DateTime.utc_now())
      |> Repo.aggregate(:count)

    %{
      persistent_total_entries: total_entries,
      persistent_expired_entries: expired_entries,
      persistent_active_entries: total_entries - expired_entries
    }
  end
end