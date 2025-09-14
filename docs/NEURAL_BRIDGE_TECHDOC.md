# NeuralBridge - Documentação Técnica

## 📋 Visão Geral

**NeuralBridge** é um proxy LLM inteligente construído em Elixir/Phoenix que atua como uma camada intermediária entre aplicações cliente e provedores de LLM externos. O sistema implementa uma estratégia de fallback em cascata: Cache → RAG → LLM Local/OpenAI → API B externa.

## 🏗️ Arquitetura

### Componentes Principais

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Cliente A     │───▶│  NeuralBridge   │───▶│    API B        │
│   (Projeto A)   │    │     Proxy       │    │   (Fallback)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Cache + RAG +  │
                    │  LLM (OpenAI/   │
                    │     Ollama)     │
                    └─────────────────┘
```

### Pipeline de Decisão

1. **Cache Check** - Verifica cache em memória (Cachex) e persistente (PostgreSQL)
2. **RAG Retrieval** - Busca contexto semântico em pgvector
3. **LLM Generation** - Gera resposta com OpenAI ou Ollama
4. **API B Fallback** - Usa API externa se confiança < threshold
5. **Logging & Training** - Registra todos os pares (query → response)

## 🔧 Stack Tecnológico

- **Phoenix Framework** - API REST + WebSockets
- **Oban** - Processamento de jobs em background
- **Cachex + ETS** - Cache híbrido (memória + PostgreSQL)
- **PostgreSQL + pgvector** - Banco principal + busca semântica
- **PromEx** - Observabilidade e métricas
- **Req/Finch** - Cliente HTTP para APIs externas
- **Broadway** - Ingestão de dados em larga escala

## 📊 Esquema do Banco de Dados

### Tabelas Principais

```sql
-- Conversas e sessões
conversations (id, session_id, user_id, metadata, last_activity_at)
messages (id, conversation_id, role, content, source, confidence_score)

-- Base de conhecimento (RAG)
knowledge_chunks (id, source_document, content, embedding, metadata)

-- Logs e treinamento
query_logs (id, query, response, source, confidence_score, api_b_called)
training_jobs (id, status, job_type, progress_percentage, results)

-- Cache persistente
cache_entries (id, query_hash, query, response, hit_count, expires_at)
```

## 🚀 APIs e Endpoints

### REST API

```http
POST   /api/proxy/query           # Processa query principal
GET    /api/proxy/health          # Health check do sistema
GET    /api/proxy/stats           # Estatísticas do proxy

GET    /api/conversations/:id     # Histórico da conversa
DELETE /api/conversations/:id     # Remove conversa

POST   /api/knowledge/ingest      # Ingere documentos (RAG)
GET    /api/knowledge/documents   # Lista documentos
DELETE /api/knowledge/documents/:doc # Remove documento

POST   /api/training/jobs         # Cria job de treinamento
GET    /api/training/jobs         # Lista jobs
GET    /api/training/jobs/:id     # Status do job

GET    /api/cache/stats           # Estatísticas do cache
DELETE /api/cache                 # Limpa cache
```

### WebSocket API

```javascript
// Conecta ao canal
channel = socket.channel("proxy:session_123", {user_id: "user_456"})

// Envia query
channel.push("query", {query: "Como funciona IA?"})

// Recebe resposta
channel.on("response", payload => {
  console.log(payload.response, payload.metadata)
})

// Streaming em tempo real
channel.push("stream_query", {query: "Explique machine learning"})
channel.on("stream_token", token => process(token))
channel.on("stream_complete", () => finish())
```

## 🔄 Fluxo de Processamento

### 1. Recebimento da Query
```elixir
# Cliente → ProxyController → ConversationServer
ConversationServer.process_query(pid, "Como criar um chatbot?")
```

### 2. Pipeline de Decisão
```elixir
def process_query_pipeline(query, state, opts) do
  context = build_context(state.messages)

  # Etapa 1: Verifica cache
  case Cache.get(query, context) do
    {:ok, cached_response} ->
      {:ok, cached_response, %{source: "cache"}}

    {:error, :not_found} ->
      # Etapa 2: RAG + LLM
      case process_with_rag_and_llm(query, context) do
        {:ok, response, metadata} ->
          Cache.put(query, context, response)
          {:ok, response, metadata}

        {:error, :low_confidence} ->
          # Etapa 3: Fallback API B
          process_with_api_b(query, context)
      end
  end
end
```

### 3. Geração com RAG
```elixir
def process_with_rag_and_llm(query, context) do
  # Busca contexto semântico
  {:ok, rag_context} = RAG.retrieve(query, limit: 5)

  # Gera resposta com LLM
  {:ok, response, confidence} = LLM.generate_response(
    query, context, rag_context, model: "gpt-4"
  )

  # Valida com guardrails
  case Guardrails.validate_response(response, query) do
    {:ok, validated} when confidence >= 0.7 ->
      {:ok, validated, %{source: "llm", confidence_score: confidence}}
    _ ->
      {:error, :low_confidence}
  end
end
```

## 🤖 Configuração de Modelos

### OpenAI
```elixir
# config/config.exs
config :neural_bridge, :openai_api_key, System.get_env("OPENAI_API_KEY")

# Uso com modelo específico
LLM.generate_response(query, context, rag_context,
  provider: :openai,
  model: "gpt-4-turbo",
  temperature: 0.7
)
```

### Ollama
```elixir
# Uso com modelo específico do Ollama
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

### Workers Implementados

1. **EmbedJob** - Gera embeddings para chunks de conhecimento
2. **TrainJob** - Fine-tuning e distillation de modelos
3. **CacheCleanupWorker** - Limpeza automática de cache
4. **TrainingDatasetWorker** - Análise diária e trigger de treinamento

```elixir
# Agenda job de embedding
NeuralBridge.Workers.EmbedJob.enqueue_chunk_embedding(chunk_id)

# Cria job de fine-tuning
NeuralBridge.Workers.TrainJob.create_training_job("fine_tune", %{
  dataset_limit: 1000,
  learning_rate: 0.0001,
  epochs: 3
})
```

## 🛡️ Guardrails e Segurança

### Validações Implementadas
- **Detecção de toxicidade** - Patterns para conteúdo prejudicial
- **Filtragem PII** - Remove informações pessoais (CPF, email, etc)
- **Validação de qualidade** - Comprimento, repetição, relevância
- **Validação JSON Schema** - Para responses estruturadas

```elixir
# Exemplo de uso
case Guardrails.validate_response(response, query) do
  {:ok, clean_response} ->
    # Response aprovada
  {:error, :content_safety_violation} ->
    # Conteúdo bloqueado
  {:error, :low_relevance} ->
    # Resposta não relevante
end
```

## 📊 Métricas e Observabilidade

### Métricas Telemetry
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

## 🚀 Deploy e Configuração

### Variáveis de Ambiente
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

## 🔧 Comandos Úteis

```bash
# Setup inicial
mix deps.get
mix ecto.create
mix ecto.migrate

# Desenvolvimento
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

## 🎯 Casos de Uso

### 1. Chatbot Inteligente
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

### 2. Sistema de Suporte
- Cache automático de perguntas frequentes
- RAG com base de conhecimento da empresa
- Fallback para agentes humanos (API B)
- Treinamento contínuo com feedback

### 3. Assistente de Código
- Análise de repositórios via RAG
- Sugestões de código com contexto
- Revisão automática de pull requests
- Documentação automática

## 🔮 Próximos Passos

1. **pgvector Integration** - Habilitar busca semântica real
2. **Função Calling** - Suporte a tools/functions do OpenAI
3. **Multi-tenant** - Isolamento por organização
4. **Rate Limiting** - Controle de taxa por usuário
5. **A/B Testing** - Testes entre diferentes modelos
6. **Fine-tuning Pipeline** - Automação completa de treinamento

---

## 📞 Suporte

Para dúvidas técnicas ou contribuições, consulte:
- Logs: `mix phx.server` ou `/dev/dashboard`
- Métricas: PromEx dashboards
- Jobs: Oban Web UI
- Código: Repositório no GitHub

**Versão:** 1.0.0
**Última atualização:** 2024
**Maintainer:** NeuralBridge Team