# NeuralBridge - Technical Documentation

## 📋 Overview

**NeuralBridge** is an intelligent LLM proxy built in Elixir/Phoenix that acts as an intermediary layer between client applications and external LLM providers. The system implements a cascading fallback strategy: Cache → RAG → Local LLM/OpenAI → External API B.

## 🏗️ Architecture

### Main Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client A      │───▶│  NeuralBridge   │───▶│    API B        │
│   (Project A)   │    │     Proxy       │    │   (Fallback)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Cache + RAG +  │
                    │  LLM (OpenAI/   │
                    │     Ollama)     │
                    └─────────────────┘
```

### Decision Pipeline

1. **Cache Check** - Checks in-memory (Cachex) and persistent (PostgreSQL) cache
2. **RAG Retrieval** - Searches semantic context in pgvector
3. **LLM Generation** - Generates response with OpenAI or Ollama
4. **API B Fallback** - Uses external API if confidence < threshold
5. **Logging & Training** - Records all pairs (query → response)

## 🔧 Technology Stack

- **Phoenix Framework** - REST API + WebSockets
- **Oban** - Background job processing
- **Cachex + ETS** - Hybrid cache (memory + PostgreSQL)
- **PostgreSQL + pgvector** - Main database + semantic search
- **PromEx** - Observability and metrics
- **Req/Finch** - HTTP client for external APIs
- **Broadway** - Large-scale data ingestion

## 📊 Database Schema

### Main Tables

```sql
-- Conversations and sessions
conversations (id, session_id, user_id, metadata, last_activity_at)
messages (id, conversation_id, role, content, source, confidence_score)

-- Knowledge base (RAG)
knowledge_chunks (id, source_document, content, embedding, metadata)

-- Logs and training
query_logs (id, query, response, source, confidence_score, api_b_called)
training_jobs (id, status, job_type, progress_percentage, results)

-- Persistent cache
cache_entries (id, query_hash, query, response, hit_count, expires_at)
```

## 🚀 APIs and Endpoints

### REST API

```http
POST   /api/proxy/query           # Processes main query
GET    /api/proxy/health          # System health check
GET    /api/proxy/stats           # Proxy statistics

GET    /api/conversations/:id     # Conversation history
DELETE /api/conversations/:id     # Remove conversation

POST   /api/knowledge/ingest      # Ingest documents (RAG)
GET    /api/knowledge/documents   # List documents
DELETE /api/knowledge/documents/:doc # Remove document

POST   /api/training/jobs         # Create training job
GET    /api/training/jobs         # List jobs
GET    /api/training/jobs/:id     # Job status

GET    /api/cache/stats           # Cache statistics
DELETE /api/cache                 # Clear cache
```

### WebSocket API

```javascript
// Connect to channel
channel = socket.channel("proxy:session_123", {user_id: "user_456"})

// Send query
channel.push("query", {query: "How does AI work?"})

// Receive response
channel.on("response", payload => {
  console.log(payload.response, payload.metadata)
})

// Real-time streaming
channel.push("stream_query", {query: "Explain machine learning"})
channel.on("stream_token", token => process(token))
channel.on("stream_complete", () => finish())
```

## 🔄 Processing Flow

### 1. Query Reception
```elixir
# Client → ProxyController → ConversationServer
ConversationServer.process_query(pid, "How to create a chatbot?")
```

### 2. Decision Pipeline
```elixir
def process_query_pipeline(query, state, opts) do
  context = build_context(state.messages)

  # Step 1: Check cache
  case Cache.get(query, context) do
    {:ok, cached_response} ->
      {:ok, cached_response, %{source: "cache"}}

    {:error, :not_found} ->
      # Step 2: RAG + LLM
      case process_with_rag_and_llm(query, context) do
        {:ok, response, metadata} ->
          Cache.put(query, context, response)
          {:ok, response, metadata}

        {:error, :low_confidence} ->
          # Step 3: Fallback API B
          process_with_api_b(query, context)
      end
  end
end
```

### 3. RAG Generation
```elixir
def process_with_rag_and_llm(query, context) do
  # Search semantic context
  {:ok, rag_context} = RAG.retrieve(query, limit: 5)

  # Generate response with LLM
  {:ok, response, confidence} = LLM.generate_response(
    query, context, rag_context, model: "gpt-4"
  )

  # Validate with guardrails
  case Guardrails.validate_response(response, query) do
    {:ok, validated} when confidence >= 0.7 ->
      {:ok, validated, %{source: "llm", confidence_score: confidence}}
    _ ->
      {:error, :low_confidence}
  end
end
```

## 🤖 Model Configuration

### OpenAI
```elixir
# config/config.exs
config :neural_bridge, :openai_api_key, System.get_env("OPENAI_API_KEY")

# Use with specific model
LLM.generate_response(query, context, rag_context,
  provider: :openai,
  model: "gpt-4-turbo",
  temperature: 0.7
)
```

### Ollama
```elixir
# Use with specific model do Ollama
LLM.generate_response(query, context, rag_context,
  provider: :ollama,
  model: "llama2:13b",
  temperature: 0.5
)

# Embeddings com Ollama
LLM.generate_embedding(text,
  provider: :ollama,
  model: "nomic-embed-text"
)
```

## 📈 Jobs em Background

### Implemented Workers

1. **EmbedJob** - Generates embeddings for knowledge chunks
2. **TrainJob** - Fine-tuning and model distillation
3. **CacheCleanupWorker** - Automatic cache cleanup
4. **TrainingDatasetWorker** - Daily analysis and training trigger

```elixir
# Schedule embedding job
NeuralBridge.Workers.EmbedJob.enqueue_chunk_embedding(chunk_id)

# Create fine-tuning job
NeuralBridge.Workers.TrainJob.create_training_job("fine_tune", %{
  dataset_limit: 1000,
  learning_rate: 0.0001,
  epochs: 3
})
```

## 🛡️ Guardrails and Security

### Implemented Validations
- **Toxicity detection** - Patterns for harmful content
- **PII filtering** - Removes personal information (CPF, email, etc)
- **Quality validation** - Length, repetition, relevance
- **JSON Schema validation** - For structured responses

```elixir
# Usage example
case Guardrails.validate_response(response, query) do
  {:ok, clean_response} ->
    # Response approved
  {:error, :content_safety_violation} ->
    # Content blocked
  {:error, :low_relevance} ->
    # Response not relevant
end
```

## 📊 Metrics and Observability

### Telemetry Metrics
- `neural_bridge.queries.total` - Total de queries processadas
- `neural_bridge.cache.hit_rate` - Taxa de acerto do cache
- `neural_bridge.api_b.fallbacks.total` - Fallbacks para API B
- `neural_bridge.llm.confidence_score` - Scores de confiança
- `neural_bridge.training.jobs.total` - Jobs de treinamento

### Dashboards PromEx
- Dashboard de aplicação (Beam/Phoenix)
- Dashboard customizado para métricas do proxy LLM
- Monitoramento de Oban jobs
- Estatísticas de banco (Ecto)

## 🚀 Deploy and Configuration

### Environment Variables
```bash
# LLM Providers
export OPENAI_API_KEY="sk-..."
export OLLAMA_URL="http://localhost:11434"

# API B Fallback
export API_B_ENDPOINT="https://api.external.com"
export API_B_KEY="..."

# Database
export DATABASE_URL="postgresql://user:pass@localhost/neural_bridge_prod"
```

### Docker Compose (Exemplo)
```yaml
version: '3.8'
services:
  neural_bridge:
    build: .
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db/neural_bridge
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      - db

  db:
    image: pgvector/pgvector:pg15
    environment:
      - POSTGRES_DB=neural_bridge
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

## 🔧 Useful Commands

```bash
# Initial setup
mix deps.get
mix ecto.create
mix ecto.migrate

# Development
mix phx.server
iex -S mix phx.server

# Jobs em background
iex> Oban.start_job(NeuralBridge.Workers.CacheCleanupWorker.new(%{}))

# Cache management
iex> NeuralBridge.Cache.clear_all()
iex> NeuralBridge.Cache.stats()

# RAG ingestion
iex> NeuralBridge.RAG.ingest_document(content, "doc1.pdf")
```

## 🎯 Use Cases

### 1. Intelligent Chatbot
```javascript
// Frontend conecta via WebSocket
const response = await fetch('/api/proxy/query', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    query: "Como implementar autenticação JWT?",
    session_id: "user_session_123",
    user_id: "user_456"
  })
})
```

### 2. Support System
- Automatic caching of frequently asked questions
- RAG with company knowledge base
- Fallback to human agents (API B)
- Continuous training with feedback

### 3. Code Assistant
- Repository analysis via RAG
- Context-aware code suggestions
- Automatic pull request review
- Automatic documentation

## 🔮 Next Steps

1. **pgvector Integration** - Habilitar busca semântica real
2. **Função Calling** - Suporte a tools/functions do OpenAI
3. **Multi-tenant** - Isolamento por organização
4. **Rate Limiting** - Controle de taxa por usuário
5. **A/B Testing** - Testes entre diferentes modelos
6. **Fine-tuning Pipeline** - Automação completa de treinamento

---

## 📞 Support

For technical questions or contributions, consult:
- Logs: `mix phx.server` or `/dev/dashboard`
- Metrics: PromEx dashboards
- Jobs: Oban Web UI
- Code: GitHub repository

**Version:** 1.0.0
**Last update:** 2024
**Maintainer:** NeuralBridge Team