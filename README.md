# 🧠 NeuralBridge - Intelligent LLM Proxy

> **Advanced proxy between applications and LLM providers with .env configuration**

NeuralBridge is an intelligent proxy that acts as an intermediary between your applications and different LLM providers (OpenAI, Ollama), implementing intelligent caching, RAG (Retrieval-Augmented Generation), security guardrails, and automatic fallback. Easily configure which provider to use as default via environment variables.

## ✨ Key Features

- ⚙️ **.env Configuration** - Define default provider (OpenAI/Ollama) via environment variables
- 🔄 **Intelligent Pipeline** - Cache → RAG → LLM → API B (fallback)
- 🤖 **Multi-Provider** - OpenAI and Ollama with configurable models
- 🧠 **Integrated RAG** - Semantic search in knowledge base
- 🛡️ **Guardrails** - Security and quality validation
- 📊 **Observability** - Real-time metrics and telemetry
- 🔄 **Background Jobs** - Asynchronous processing of embeddings and training
- 💾 **Hybrid Cache** - Memory + persistent PostgreSQL
- 🌐 **WebSockets** - Real-time response streaming

## 🚀 Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd neural_bridge

# Install dependencies
mix setup

# Setup the database
mix ecto.create
mix ecto.migrate
```

### 2. Configuration (.env)

**Option 1 - OpenAI:**
```bash
# Copy the example file
cp .env.example .env

# Configure for OpenAI
echo "LLM_PROVIDER=openai" > .env
echo "OPENAI_API_KEY=sk-your-key-here" >> .env
echo "OPENAI_DEFAULT_MODEL=gpt-4" >> .env
```

**Option 2 - Ollama:**
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Download models
ollama pull llama2

# Configure for Ollama
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env
```

### 3. Execution

```bash
# Start the server
mix phx.server

# Test the configuration
curl http://localhost:4000/api/proxy/health
```

## 🔧 Configuration via .env

NeuralBridge uses environment variables to automatically determine which LLM provider to use:

### Example .env file:

```bash
# Main provider (openai or ollama)
LLM_PROVIDER=ollama

# OpenAI configuration
OPENAI_API_KEY=sk-your-key-here
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7

# Ollama configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2

# Cache and other settings
CACHE_ENABLED=true
CACHE_TTL_SECONDS=3600
```

### Supported Models:

**OpenAI:** `gpt-4`, `gpt-4-turbo`, `gpt-3.5-turbo`

**Ollama:** `llama2`, `codellama`, `mistral`, `neural-chat`, custom models (`llama2:7b-chat`)

## 📡 API REST

### Main Endpoint

```bash
# Uses default .env configuration
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Explain machine learning",
    "session_id": "my_session_123"
  }'

# Provider override in request
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Explain machine learning",
    "session_id": "my_session_123",
    "provider": "openai",
    "model": "gpt-4"
  }'
```

### Monitoring Endpoints

```bash
# Check health
curl http://localhost:4000/api/proxy/health

# Get statistics
curl http://localhost:4000/api/proxy/stats
```

## 🔄 Processing Pipeline

```
1. 💾 Cache Check → Instant response if found
2. 🧠 RAG Retrieval → Search context in knowledge base
3. 🤖 LLM Generation → OpenAI or Ollama
4. 🛡️ Guardrails → Security validation
5. 🔄 API B Fallback → Automatic fallback if needed
```

## 📊 Observability

- **PromEx Integration** - Prometheus metrics
- **Real-time Stats** - Web interface with live metrics
- **Health Checks** - Monitoring of all components
- **Telemetry Events** - Detailed operation tracking

## 🔧 Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│  Client App │────│ NeuralBridge │────│   LLM APIs  │
└─────────────┘    └──────────────┘    └─────────────┘
                           │
                   ┌───────┴───────┐
                   │               │
              ┌─────────┐    ┌──────────┐
              │  Cache  │    │   RAG    │
              └─────────┘    └──────────┘
                   │              │
              ┌─────────┐    ┌──────────┐
              │ Cachex  │    │PostgreSQL│
              └─────────┘    └──────────┘
```

### Main Components:

- **ConversationServer** - GenServer for session management
- **Cache** - Hybrid Cachex + PostgreSQL system
- **RAG** - Retrieval-Augmented Generation with embeddings
- **LLM** - Unified OpenAI/Ollama client
- **Guardrails** - Security and quality validation
- **Background Jobs** - Oban for asynchronous processing

## 📚 Documentation

- **[Configuration Guide](docs/CONFIG_GUIDE.md)** - Detailed OpenAI/Ollama setup
- **[API Interactions](docs/API_INTERACTIONS.md)** - Complete API documentation
- **[WebSocket Guide](docs/WEBSOCKET_INTERACTIONS.md)** - Real-time streaming
- **[Background Jobs](docs/BACKGROUND_JOBS.md)** - Asynchronous job system

## 🛠️ Development

### File Structure

```
lib/
├── neural_bridge/
│   ├── application.ex          # Main supervisor
│   ├── conversation_server.ex  # Session management
│   ├── cache.ex               # Cache system
│   ├── rag.ex                 # Retrieval-Augmented Generation
│   ├── llm.ex                 # Unified LLM client
│   ├── guardrails.ex          # Security validations
│   └── workers/               # Background jobs
└── neural_bridge_web/
    ├── channels/              # WebSocket channels
    ├── controllers/           # REST controllers
    └── router.ex             # Routing
```

### Background Jobs

- **EmbedJob** - Embedding generation for RAG
- **TrainJob** - Model training (fine-tuning/distillation)
- **CacheCleanupWorker** - Automatic cache cleanup
- **TrainingDatasetWorker** - Analysis and training triggers

### Run Tests

```bash
mix test
```

### Run in Development

```bash
# With live reloading
mix phx.server

# In interactive console
iex -S mix phx.server
```

## 📈 Production Monitoring

### Available Metrics

- Cache hit/miss rates
- Response times per provider
- Confidence scores
- API B fallback rates
- Training job performance
- System resources

### Health Checks

- Database connectivity
- Cache system status
- LLM provider availability
- API B connectivity

## 🔐 Security

- **Automatic Guardrails** for content validation
- **PII Detection** and removal
- **Rate limiting** per session
- **Input sanitization**
- **Secure session management**

## 🚀 Production Deployment

```bash
# Build release
MIX_ENV=prod mix release

# Execute
_build/prod/rel/neural_bridge/bin/neural_bridge start
```

### Environment Variables

```bash
# LLM Providers
OPENAI_API_KEY=sk-...
OLLAMA_BASE_URL=http://localhost:11434

# Database
DATABASE_URL=ecto://user:pass@localhost/neural_bridge_prod

# Cache
CACHE_TTL_SECONDS=3600
CACHE_MAX_SIZE=10000

# Security
SECRET_KEY_BASE=your-secret-key
```

## 🤝 Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Useful Links

- **Phoenix Framework**: https://www.phoenixframework.org/
- **OpenAI API**: https://platform.openai.com/docs
- **Ollama**: https://ollama.com/
- **Oban**: https://github.com/sorentwo/oban
- **PromEx**: https://github.com/akoutmos/prom_ex

---

**🎉 Get started now: `mix phx.server` and access `http://localhost:4000`**