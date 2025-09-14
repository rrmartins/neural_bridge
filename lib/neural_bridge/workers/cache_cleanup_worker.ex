defmodule NeuralBridge.Workers.CacheCleanupWorker do
  use Oban.Worker, queue: :default

  alias NeuralBridge.Cache
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting cache cleanup task")

    # Clean up expired cache entries
    Cache.cleanup_expired()

    # Clean up in-memory cache statistics
    cleanup_memory_cache()

    Logger.info("Cache cleanup completed")
    :ok
  end

  defp cleanup_memory_cache do
    # Get cache statistics before cleanup
    stats_before = Cache.stats()

    # Cachex automatically handles TTL expiration, but we can force a cleanup
    case Cachex.purge(:neural_bridge_cache) do
      {:ok, purged_count} ->
        Logger.info("Purged #{purged_count} expired entries from memory cache")

      {:error, reason} ->
        Logger.warning("Failed to purge memory cache: #{inspect(reason)}")
    end

    # Log cache performance metrics
    stats_after = Cache.stats()
    log_cache_metrics(stats_before, stats_after)
  end

  defp log_cache_metrics(stats_before, stats_after) do
    memory_size_before = Map.get(stats_before, :memory, 0)
    memory_size_after = Map.get(stats_after, :memory, 0)
    memory_freed = memory_size_before - memory_size_after

    if memory_freed > 0 do
      Logger.info("Cache cleanup freed #{memory_freed} bytes of memory")
    end

    # Emit cache metrics
    :telemetry.execute(
      [:neural_bridge, :cache, :cleanup],
      %{
        memory_freed: memory_freed,
        size_before: memory_size_before,
        size_after: memory_size_after
      },
      %{}
    )
  end
end