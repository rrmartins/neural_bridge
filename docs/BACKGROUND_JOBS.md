# NeuralBridge - Background Jobs & Workers

## ⚙️ Oban Workers Overview

O NeuralBridge utiliza **Oban** para processamento assíncrono de tarefas pesadas, permitindo que a API principal permaneça responsiva enquanto processa embeddings, treinamentos e manutenção do sistema.

---

## 🧠 EmbedJob - Geração de Embeddings

### Responsabilidades
- Gerar embeddings para chunks de conhecimento
- Processar documentos em lote
- Reprocessar embeddings existentes

### Interações

#### 1. Processar Chunk Individual
```elixir
# Enfileirar job para chunk específico
{:ok, job} = NeuralBridge.Workers.EmbedJob.enqueue_chunk_embedding(chunk_id)

# Job executado automaticamente
%Oban.Job{
  args: %{"knowledge_chunk_id" => "chunk_uuid_123"}
}
```

**Fluxo de Execução:**
1. Busca chunk no banco de dados
2. Verifica se já possui embedding
3. Chama LLM para gerar embedding
4. Salva embedding no banco
5. Atualiza timestamp de processamento

#### 2. Processar Documento Completo
```elixir
# Processa todos os chunks de um documento
{:ok, job} = NeuralBridge.Workers.EmbedJob.enqueue_document_batch("manual_jwt.pdf")

# Job processará sequencialmente todos os chunks
```

**Exemplo de Log:**
```
[info] Generating embedding for chunk: chunk_uuid_123
[info] Successfully generated embedding for chunk: chunk_uuid_123
[info] Processing embeddings for 12 chunks in document: manual_jwt.pdf
[info] Processing chunk 1/12
[info] Processing chunk 2/12
...
[info] Completed embedding generation for document manual_jwt.pdf: 12/12 successful
```

#### 3. Reprocessar Todos os Embeddings
```elixir
# Útil para atualizar modelo de embeddings
{:ok, job} = NeuralBridge.Workers.EmbedJob.enqueue_reprocess_all()
```

### Error Handling
- **Chunk não encontrado**: Job falha com `:chunk_not_found`
- **Erro na API**: Retry automático até 3 tentativas
- **Falha no embedding**: Log de erro, continua próximo chunk

---

## 🎓 TrainJob - Treinamento de Modelos

### Tipos de Treinamento

#### 1. Fine-tuning
Treina modelo baseado em dados de feedback positivo.

```elixir
# Criar job de fine-tuning
config = %{
  "dataset_limit" => 1000,
  "learning_rate" => 0.0001,
  "epochs" => 3,
  "batch_size" => 4,
  "validation_split" => 0.2
}

{:ok, job} = NeuralBridge.Workers.TrainJob.create_training_job("fine_tune", config)
```

**Pipeline de Fine-tuning:**
1. **Dataset Preparation**
   - Busca query_logs com feedback_score >= 4
   - Filtra dados não utilizados para treinamento
   - Formata para padrão de mensagens
   - Marca como `used_for_training: true`

2. **Model Configuration**
   - Define hiperparâmetros
   - Configura validação
   - Prepara ambiente de treinamento

3. **Training Execution**
   - Simula processo de treinamento
   - Atualiza progresso em tempo real
   - Emite métricas telemetry

4. **Results Storage**
   - Salva métricas de treinamento
   - Gera ID do modelo
   - Registra tempo total

#### 2. Distillation
Treina modelo menor baseado em respostas de API B (teacher model).

```elixir
# Criar job de distillation
config = %{
  "sample_limit" => 500,
  "teacher_confidence_threshold" => 0.8
}

{:ok, job} = NeuralBridge.Workers.TrainJob.create_training_job("distillation", config)
```

**Pipeline de Distillation:**
1. **Teacher Data Collection**
   - Coleta respostas de alta qualidade da API B
   - Filtra por confidence_score >= 0.8
   - Prepara dataset teacher-student

2. **Knowledge Transfer**
   - Treina modelo local para imitar API B
   - Otimiza para manter conhecimento
   - Reduz dependência de API externa

### Monitoramento de Progresso

```elixir
# Acompanhar job em tempo real
job = Repo.get(TrainingJob, job_id)

case job.status do
  "pending" -> "Aguardando na fila"
  "running" -> "#{job.progress_percentage}% concluído"
  "completed" -> "Concluído: #{inspect(job.results)}"
  "failed" -> "Erro: #{job.error_message}"
end
```

**Métricas Emitidas:**
```elixir
:telemetry.execute(
  [:neural_bridge, :training, :progress],
  %{progress_percentage: 65.5},
  %{job_id: job.id, job_type: "fine_tune"}
)
```

---

## 🧹 CacheCleanupWorker - Manutenção do Cache

### Execução Programada
```elixir
# Configurado no cron para executar a cada hora
{"0 * * * *", NeuralBridge.Workers.CacheCleanupWorker}
```

### Operações de Limpeza

#### 1. Cache Persistente
- Remove entradas expiradas do PostgreSQL
- Limpa entries com `expires_at < now()`

#### 2. Cache em Memória
- Force purge no Cachex
- Libera memória não utilizada
- Coleta estatísticas

#### 3. Métricas de Performance
```elixir
# Exemplo de logs gerados
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

## 📊 TrainingDatasetWorker - Análise Automática

### Execução Diária
```elixir
# Executado diariamente às 2h da manhã
{"0 2 * * *", NeuralBridge.Workers.TrainingDatasetWorker}
```

### Análise de Dados

#### 1. Coleta de Métricas (24h)
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

#### 2. Triggers Automáticos

**Fine-tuning Trigger:**
```elixir
def should_trigger_fine_tuning?(stats) do
  stats.positive_feedback >= 50 and      # Feedback suficiente
  stats.avg_confidence >= 0.6 and       # Confiança razoável
  stats.fallback_rate < 0.3              # Poucos fallbacks
end
```

**Distillation Trigger:**
```elixir
def should_trigger_distillation?(stats) do
  stats.fallback_rate > 0.4 and         # Muitos fallbacks
  stats.api_b_fallbacks >= 100          # Dados suficientes da API B
end
```

#### 3. Configuração Adaptativa

```elixir
# Learning rate baseado na confiança média
def calculate_learning_rate(stats) do
  base_rate = 0.0001

  case stats.avg_confidence do
    conf when conf >= 0.8 -> base_rate * 0.5  # Conservador
    conf when conf >= 0.6 -> base_rate         # Normal
    _ -> base_rate * 2.0                       # Agressivo
  end
end
```

### Exemplo de Trigger Automático

```elixir
# Log de exemplo quando triggering acontece
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
    default: 10,      # Jobs gerais (cleanup, análise)
    embeddings: 5,    # Geração de embeddings
    training: 3,      # Jobs de treinamento (mais recursos)
    api_calls: 20     # Chamadas externas (alta concorrência)
  ]
```

### Job Dependencies

#### Sequential Processing
```elixir
# 1. Ingere documento
{:ok, chunks} = RAG.ingest_document(content, "doc.pdf")

# 2. Processa embeddings em lote
{:ok, embed_job} = EmbedJob.enqueue_document_batch("doc.pdf")

# 3. Aguarda conclusão para usar em RAG
Process.sleep(5000)  # Em prod, usar job dependency
```

#### Conditional Jobs
```elixir
# TrainingDatasetWorker decide qual job criar
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
# Métricas importantes para monitorar
def get_job_stats do
  %{
    # Jobs por status
    jobs_by_status: Oban.count_jobs_by_state(),

    # Performance por queue
    queue_performance: %{
      "embeddings" => %{avg_duration_ms: 2340, success_rate: 0.98},
      "training" => %{avg_duration_ms: 180000, success_rate: 0.95},
      "default" => %{avg_duration_ms: 450, success_rate: 0.99}
    },

    # Jobs recentes
    recent_failures: get_recent_failed_jobs(),
    active_training_jobs: get_active_training_jobs()
  }
end
```

### Alerting Rules

```elixir
# Regras de alerta baseadas em métricas
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
# Configurações de performance por job
defmodule EmbedJob do
  use Oban.Worker,
    queue: :embeddings,
    max_attempts: 3,
    priority: 1,           # Prioridade média
    tags: ["embedding"]
end

defmodule TrainJob do
  use Oban.Worker,
    queue: :training,
    max_attempts: 1,       # Não retry jobs de treinamento
    priority: 0,           # Prioridade alta
    tags: ["training", "ml"]
end
```

---

## 🚀 Production Considerations

### Scaling Workers
```elixir
# Configuração para produção
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
    training: [limit: 2, paused: false],  # Limitado por recursos
    api_calls: [limit: 50, paused: false]
  ]
```

### Resource Management
- **Memory**: Jobs de embedding usam ~50MB por chunk
- **CPU**: Jobs de treinamento são CPU-intensivos
- **I/O**: Cache cleanup é I/O bound
- **Network**: API calls dependem da rede

### Error Recovery
```elixir
# Estratégias de recuperação por tipo de erro
def handle_job_error(job, error) do
  case {job.worker, error} do
    {"EmbedJob", %{reason: :api_rate_limit}} ->
      # Reagendar com backoff exponencial
      schedule_in(minutes: job.attempt * 5)

    {"TrainJob", %{reason: :insufficient_data}} ->
      # Cancelar job, não retry
      {:cancel, "Not enough training data"}

    {"CacheCleanupWorker", _} ->
      # Sempre retry cleanup jobs
      {:retry, delay: :timer.minutes(30)}
  end
end
```

Essa documentação cobre todo o sistema de background jobs do NeuralBridge! 🔧