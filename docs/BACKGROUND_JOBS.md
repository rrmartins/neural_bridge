# NeuralBridge - Background Jobs & Workers

## ⚙️ Oban Workers Overview

NeuralBridge uses **Oban** for asynchronous processing of heavy tasks, allowing the main API to remain responsive while processing embeddings, training, and system maintenance.

---

## 🧠 EmbedJob - Embedding Generation

### Responsibilities
- Generate embeddings for knowledge chunks
- Process documents in batches
- Reprocess existing embeddings

### Interactions

#### 1. Process Individual Chunk
```elixir
# Queue job for specific chunk
{:ok, job} = NeuralBridge.Workers.EmbedJob.enqueue_chunk_embedding(chunk_id)

# Job executed automatically
%Oban.Job{
  args: %{"knowledge_chunk_id" => "chunk_uuid_123"}
}
```

**Execution Flow:**
1. Fetch chunk from database
2. Check if embedding already exists
3. Call LLM to generate embedding
4. Save embedding to database
5. Update processing timestamp

#### 2. Process Complete Document
```elixir
# Process all chunks from a document
{:ok, job} = NeuralBridge.Workers.EmbedJob.enqueue_document_batch("manual_jwt.pdf")

# Job will sequentially process all chunks
```

**Log Example:**
```
[info] Generating embedding for chunk: chunk_uuid_123
[info] Successfully generated embedding for chunk: chunk_uuid_123
[info] Processing embeddings for 12 chunks in document: manual_jwt.pdf
[info] Processing chunk 1/12
[info] Processing chunk 2/12
...
[info] Completed embedding generation for document manual_jwt.pdf: 12/12 successful
```

#### 3. Reprocess All Embeddings
```elixir
# Useful for updating embedding model
{:ok, job} = NeuralBridge.Workers.EmbedJob.enqueue_reprocess_all()
```

### Error Handling
- **Chunk not found**: Job fails with `:chunk_not_found`
- **API error**: Automatic retry up to 3 attempts
- **Embedding failure**: Log error, continue to next chunk

---

## 🎓 TrainJob - Model Training

### Training Types

#### 1. Fine-tuning
Trains model based on positive feedback data.

```elixir
# Create fine-tuning job
config = %{
  "dataset_limit" => 1000,
  "learning_rate" => 0.0001,
  "epochs" => 3,
  "batch_size" => 4,
  "validation_split" => 0.2
}

{:ok, job} = NeuralBridge.Workers.TrainJob.create_training_job("fine_tune", config)
```

**Fine-tuning Pipeline:**
1. **Dataset Preparation**
   - Fetch query_logs with feedback_score >= 4
   - Filter data not used for training
   - Format to message pattern
   - Mark as `used_for_training: true`

2. **Model Configuration**
   - Define hyperparameters
   - Configure validation
   - Prepare training environment

3. **Training Execution**
   - Simulate training process
   - Update progress in real-time
   - Emit telemetry metrics

4. **Results Storage**
   - Save training metrics
   - Generate model ID
   - Record total time

#### 2. Distillation
Trains smaller model based on API B responses (teacher model).

```elixir
# Create distillation job
config = %{
  "sample_limit" => 500,
  "teacher_confidence_threshold" => 0.8
}

{:ok, job} = NeuralBridge.Workers.TrainJob.create_training_job("distillation", config)
```

**Distillation Pipeline:**
1. **Teacher Data Collection**
   - Collect high-quality API B responses
   - Filter by confidence_score >= 0.8
   - Prepare teacher-student dataset

2. **Knowledge Transfer**
   - Train local model to mimic API B
   - Optimize to maintain knowledge
   - Reduce external API dependency

### Progress Monitoring

```elixir
# Track job in real-time
job = Repo.get(TrainingJob, job_id)

case job.status do
  "pending" -> "Waiting in queue"
  "running" -> "#{job.progress_percentage}% completed"
  "completed" -> "Completed: #{inspect(job.results)}"
  "failed" -> "Error: #{job.error_message}"
end
```

**Emitted Metrics:**
```elixir
:telemetry.execute(
  [:neural_bridge, :training, :progress],
  %{progress_percentage: 65.5},
  %{job_id: job.id, job_type: "fine_tune"}
)
```

---

## 🧹 CacheCleanupWorker - Cache Maintenance

### Scheduled Execution
```elixir
# Configured in cron to run every hour
{"0 * * * *", NeuralBridge.Workers.CacheCleanupWorker}
```

### Cleanup Operations

#### 1. Persistent Cache
- Remove expired entries from PostgreSQL
- Clean entries with `expires_at < now()`

#### 2. Memory Cache
- Force purge in Cachex
- Free unused memory
- Collect statistics

#### 3. Performance Metrics
```elixir
# Example of generated logs
[info] Starting cache cleanup task
[info] Purged 234 expired entries from memory cache
[info] Cache cleanup freed 15728640 bytes of memory
[info] Cache cleanup completed
```

### Telemetry Events
```elixir
:telemetry.execute(
  [:neural_bridge, :cache, :cleanup],
  %{
    memory_freed: 15728640,
    size_before: 41943040,
    size_after: 26214400
  },
  %{}
)
```

---

## 📊 TrainingDatasetWorker - Automatic Analysis

### Daily Execution
```elixir
# Executed daily at 2 AM
{"0 2 * * *", NeuralBridge.Workers.TrainingDatasetWorker}
```

### Data Analysis

#### 1. Metrics Collection (24h)
```elixir
stats = %{
  total_queries: 1247,
  avg_confidence: 0.73,
  api_b_fallbacks: 156,
  high_confidence_responses: 892,
  user_feedback_available: 234,
  positive_feedback: 178,
  fallback_rate: 0.125,  # 12.5%
  feedback_rate: 0.188   # 18.8%
}
```

#### 2. Automatic Triggers

**Fine-tuning Trigger:**
```elixir
def should_trigger_fine_tuning?(stats) do
  stats.positive_feedback >= 50 and      # Sufficient feedback
  stats.avg_confidence >= 0.6 and       # Reasonable confidence
  stats.fallback_rate < 0.3              # Few fallbacks
end
```

**Distillation Trigger:**
```elixir
def should_trigger_distillation?(stats) do
  stats.fallback_rate > 0.4 and         # Many fallbacks
  stats.api_b_fallbacks >= 100          # Sufficient API B data
end
```

#### 3. Adaptive Configuration

```elixir
# Learning rate based on average confidence
def calculate_learning_rate(stats) do
  base_rate = 0.0001

  case stats.avg_confidence do
    conf when conf >= 0.8 -> base_rate * 0.5  # Conservative
    conf when conf >= 0.6 -> base_rate         # Normal
    _ -> base_rate * 2.0                       # Aggressive
  end
end
```

### Automatic Trigger Example

```elixir
# Example log when triggering happens
[info] Training data analysis: %{
  total_queries: 1247,
  fallback_rate: 0.125,
  avg_confidence: 0.73,
  feedback_rate: 0.188
}

[info] Triggering fine-tuning job based on training data analysis
[info] Fine-tuning configuration: %{
  "trigger_reason" => "daily_analysis",
  "dataset_limit" => 356,
  "learning_rate" => 0.0001,
  "epochs" => 3
}
```

---

## 🔄 Job Orchestration

### Queue Configuration
```elixir
# config/config.exs
config :neural_bridge, Oban,
  queues: [
    default: 10,      # General jobs (cleanup, analysis)
    embeddings: 5,    # Embedding generation
    training: 3,      # Training jobs (more resources)
    api_calls: 20     # External calls (high concurrency)
  ]
```

### Job Dependencies

#### Sequential Processing
```elixir
# 1. Ingest document
{:ok, chunks} = RAG.ingest_document(content, "doc.pdf")

# 2. Process embeddings in batch
{:ok, embed_job} = EmbedJob.enqueue_document_batch("doc.pdf")

# 3. Wait for completion to use in RAG
Process.sleep(5000)  # In prod, use job dependency
```

#### Conditional Jobs
```elixir
# TrainingDatasetWorker decides which job to create
case analyze_training_data() do
  {:trigger_fine_tune, config} ->
    TrainJob.enqueue_fine_tune_job(config)

  {:trigger_distillation, config} ->
    TrainJob.enqueue_distillation_job(config)

  {:no_action_needed} ->
    Logger.info("No training needed based on current metrics")
end
```

---

## 📈 Monitoring & Observability

### Job Metrics Dashboard

```elixir
# Important metrics to monitor
def get_job_stats do
  %{
    # Jobs by status
    jobs_by_status: Oban.count_jobs_by_state(),

    # Performance by queue
    queue_performance: %{
      "embeddings" => %{avg_duration_ms: 2340, success_rate: 0.98},
      "training" => %{avg_duration_ms: 180000, success_rate: 0.95},
      "default" => %{avg_duration_ms: 450, success_rate: 0.99}
    },

    # Recent jobs
    recent_failures: get_recent_failed_jobs(),
    active_training_jobs: get_active_training_jobs()
  }
end
```

### Alerting Rules

```elixir
# Alert rules based on metrics
def check_job_health do
  cond do
    embedding_queue_depth() > 100 ->
      {:alert, "Embedding queue backed up"}

    training_failure_rate() > 0.1 ->
      {:alert, "High training job failure rate"}

    cache_cleanup_overdue?() ->
      {:alert, "Cache cleanup overdue"}

    true ->
      {:ok, "All job queues healthy"}
  end
end
```

### Performance Optimization

```elixir
# Performance configurations per job
defmodule EmbedJob do
  use Oban.Worker,
    queue: :embeddings,
    max_attempts: 3,
    priority: 1,           # Medium priority
    tags: ["embedding"]
end

defmodule TrainJob do
  use Oban.Worker,
    queue: :training,
    max_attempts: 1,       # Don't retry training jobs
    priority: 0,           # High priority
    tags: ["training", "ml"]
end
```

---

## 🚀 Production Considerations

### Scaling Workers
```elixir
# Production configuration
config :neural_bridge, Oban,
  repo: NeuralBridge.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    Oban.Plugins.Cron,
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ],
  queues: [
    default: [limit: 20, paused: false],
    embeddings: [limit: 10, paused: false],
    training: [limit: 2, paused: false],  # Limited by resources
    api_calls: [limit: 50, paused: false]
  ]
```

### Resource Management
- **Memory**: Embedding jobs use ~50MB per chunk
- **CPU**: Training jobs are CPU-intensive
- **I/O**: Cache cleanup is I/O bound
- **Network**: API calls depend on network

### Error Recovery
```elixir
# Recovery strategies by error type
def handle_job_error(job, error) do
  case {job.worker, error} do
    {"EmbedJob", %{reason: :api_rate_limit}} ->
      # Reschedule with exponential backoff
      schedule_in(minutes: job.attempt * 5)

    {"TrainJob", %{reason: :insufficient_data}} ->
      # Cancel job, don't retry
      {:cancel, "Not enough training data"}

    {"CacheCleanupWorker", _} ->
      # Always retry cleanup jobs
      {:retry, delay: :timer.minutes(30)}
  end
end
```

This documentation covers the entire NeuralBridge background jobs system! 🔧