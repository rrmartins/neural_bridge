defmodule NeuralBridge.PromEx.LLMProxyPlugin do
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      # Query processing metrics
      counter(
        "neural_bridge.queries.total",
        event_name: [:neural_bridge, :query, :processed],
        description: "Total queries processed",
        tags: [:source, :status]
      ),

      # Cache metrics
      counter(
        "neural_bridge.cache.total",
        event_name: [:neural_bridge, :cache, :accessed],
        description: "Total cache accesses",
        tags: [:result]
      ),

      distribution(
        "neural_bridge.cache.hit_rate",
        event_name: [:neural_bridge, :cache, :hit_rate],
        description: "Cache hit rate percentage",
        unit: :percent
      ),

      # API B fallback metrics
      counter(
        "neural_bridge.api_b.fallbacks.total",
        event_name: [:neural_bridge, :api_b, :fallback],
        description: "Total API B fallbacks",
        tags: [:reason]
      ),

      distribution(
        "neural_bridge.api_b.response_time",
        event_name: [:neural_bridge, :api_b, :response],
        description: "API B response time",
        unit: {:native, :millisecond}
      ),

      # LLM processing metrics
      distribution(
        "neural_bridge.llm.response_time",
        event_name: [:neural_bridge, :llm, :response],
        description: "LLM response time",
        unit: {:native, :millisecond}
      ),

      distribution(
        "neural_bridge.llm.confidence_score",
        event_name: [:neural_bridge, :llm, :confidence],
        description: "LLM confidence scores",
        unit: :percent
      ),

      # RAG metrics
      counter(
        "neural_bridge.rag.queries.total",
        event_name: [:neural_bridge, :rag, :query],
        description: "Total RAG queries",
        tags: [:status]
      ),

      distribution(
        "neural_bridge.rag.retrieval_time",
        event_name: [:neural_bridge, :rag, :retrieval],
        description: "RAG retrieval time",
        unit: {:native, :millisecond}
      ),

      # Training job metrics
      counter(
        "neural_bridge.training.jobs.total",
        event_name: [:neural_bridge, :training, :job],
        description: "Training jobs executed",
        tags: [:type, :status]
      ),

      distribution(
        "neural_bridge.training.job_duration",
        event_name: [:neural_bridge, :training, :duration],
        description: "Training job duration",
        unit: {:native, :second}
      )
    ]
  end

  @impl true
  def polling_metrics(_opts) do
    # Skip polling metrics for now - can be added when PromEx configuration is properly set up
    []
  end

  # Polling metric functions
  def active_conversations_count do
    # Count active conversation processes
    Registry.count(NeuralBridge.ConversationRegistry)
  end

  def cache_size do
    Cachex.size(:neural_bridge_cache)
  end

  def training_queue_depth do
    import Ecto.Query

    NeuralBridge.Repo.aggregate(
      from(j in "oban_jobs", where: j.queue == "training" and j.state == "available"),
      :count
    )
  end
end