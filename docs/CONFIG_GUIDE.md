# 🔧 NeuralBridge - Configuration Guide (.env)

## 🎯 Overview

This guide explains how to configure NeuralBridge using environment variables (`.env`) to automatically determine which LLM provider to use (OpenAI or Ollama) and customize all system settings.

---

## 📁 Basic Configuration

### 1. Copy the example file

```bash
cp .env.example .env
```

### 2. Configure your main provider

NeuralBridge automatically uses the provider defined in `LLM_PROVIDER`:

```bash
# To use OpenAI as default
LLM_PROVIDER=openai

# To use Ollama as default
LLM_PROVIDER=ollama
```

---

## 🤖 OpenAI Configuration

To use OpenAI as the main provider, configure:

```bash
# Main provider
LLM_PROVIDER=openai

# API key (get it from: https://platform.openai.com/api-keys)
OPENAI_API_KEY=sk-your-openai-api-key-here

# Optional settings
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7
OPENAI_MAX_TOKENS=2048
```

### Available OpenAI Models:
- `gpt-4` - Most intelligent
- `gpt-4-turbo` - Optimized speed
- `gpt-3.5-turbo` - Cost-effective

### Complete example for OpenAI:

```bash
# .env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-abc123...
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7
```

---

## 🦙 Ollama Configuration

To use Ollama as the main provider:

### 1. Install Ollama

```bash
# macOS/Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows: download from https://ollama.com/download
```

### 2. Download models

```bash
ollama pull llama2
ollama pull codellama
ollama pull mistral
ollama pull neural-chat
```

### 3. Configure .env

```bash
# Main provider
LLM_PROVIDER=ollama

# Ollama URL (default: localhost:11434)
OLLAMA_BASE_URL=http://localhost:11434

# Default model
OLLAMA_DEFAULT_MODEL=llama2
```

### Supported Ollama Models:
- `llama2` - Robust general model
- `codellama` - Specialized in code
- `mistral` - Efficient European model
- `neural-chat` - Optimized for conversations
- Custom models: `llama2:7b-chat`, `llama2:13b-chat`, etc.

### Complete example for Ollama:

```bash
# .env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=codellama
```

---

## 🔄 Dynamic Provider Switching

### Via Environment Variable

```bash
# Use OpenAI
export LLM_PROVIDER=openai
mix phx.server

# Use Ollama
export LLM_PROVIDER=ollama
mix phx.server
```

### Via API (per-request override)

Even with a default provider configured, you can specify another in the request:

```bash
# Server configured for Ollama, but using OpenAI for this call
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Explain machine learning",
    "session_id": "test_123",
    "provider": "openai",
    "model": "gpt-4"
  }'
```

---

## 📋 Complete .env File

Here's a complete example of `.env` with all options:

```bash
# ================================
# NeuralBridge - LLM Configuration
# ================================

# =====================
# Main Provider
# =====================
LLM_PROVIDER=ollama

# =====================
# OpenAI Configuration
# =====================
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7
OPENAI_MAX_TOKENS=2048

# =====================
# Ollama Configuration
# =====================
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2

# =====================
# API B (Fallback)
# =====================
API_B_ENABLED=true
API_B_URL=https://api.example.com/v1/chat
API_B_TOKEN=your-api-b-token-here
API_B_TIMEOUT_MS=30000

# =====================
# Cache Configuration
# =====================
CACHE_ENABLED=true
CACHE_TTL_SECONDS=3600
CACHE_MAX_SIZE=10000
CACHE_CLEANUP_INTERVAL_MINUTES=60

# =====================
# RAG Configuration
# =====================
RAG_ENABLED=true
RAG_SIMILARITY_THRESHOLD=0.7
RAG_MAX_CHUNKS=5
RAG_CHUNK_SIZE=1000
RAG_CHUNK_OVERLAP=200

# =====================
# Guardrails
# =====================
GUARDRAILS_ENABLED=true
GUARDRAILS_MIN_CONFIDENCE=0.7
GUARDRAILS_PII_DETECTION=true
GUARDRAILS_TOXICITY_CHECK=true

# =====================
# Background Jobs
# =====================
OBAN_ENABLED=true
EMBEDDING_QUEUE_LIMIT=5
TRAINING_QUEUE_LIMIT=3
DEFAULT_QUEUE_LIMIT=10

# =====================
# Database
# =====================
DATABASE_URL=ecto://postgres:postgres@localhost/neural_bridge_dev

# =====================
# Server Configuration
# =====================
PORT=4000
SECRET_KEY_BASE=your-secret-key-base-here
PHX_HOST=localhost

# =====================
# Monitoring
# =====================
PROM_EX_ENABLED=false
TELEMETRY_ENABLED=true
HEALTH_CHECK_INTERVAL_SECONDS=30

# =====================
# Development/Debug
# =====================
LOG_LEVEL=info
DEBUG_MODE=false
CODE_RELOADER=true
```

---

## 🧪 Testing Configuration

### 1. Check current configuration

```bash
# Test system health
curl http://localhost:4000/api/proxy/health

# View statistics
curl http://localhost:4000/api/proxy/stats
```

### 2. Test with default provider

```bash
# Use default .env configuration
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Hello, how are you?",
    "session_id": "test_session_123"
  }'
```

### 3. Test with specific provider

```bash
# Force use of OpenAI (even if Ollama is default)
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What is the capital of Brazil?",
    "session_id": "test_session_456",
    "provider": "openai",
    "model": "gpt-3.5-turbo"
  }'
```

---

## 🔄 Common Usage Scenarios

### Development with Ollama

```bash
# .env for local development
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2
CACHE_ENABLED=true
DEBUG_MODE=true
LOG_LEVEL=debug
```

### Production with OpenAI

```bash
# .env for production
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-prod-key-here
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_MAX_TOKENS=4096
CACHE_ENABLED=true
CACHE_TTL_SECONDS=7200
GUARDRAILS_ENABLED=true
PROM_EX_ENABLED=true
```

### Hybrid Environment

```bash
# OpenAI as default, Ollama available for override
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-key-here
OPENAI_DEFAULT_MODEL=gpt-4

# Ollama also configured
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=codellama

# Robust fallback
API_B_ENABLED=true
API_B_URL=https://backup-api.com/v1/chat
API_B_TOKEN=backup-token
```

---

## 🚀 Quick Start

### For OpenAI:

```bash
# 1. Configure
echo "LLM_PROVIDER=openai" > .env
echo "OPENAI_API_KEY=sk-your-key-here" >> .env

# 2. Start
mix phx.server

# 3. Test
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "Hello!", "session_id": "test"}'
```

### For Ollama:

```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Download model
ollama pull llama2

# 3. Configure
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env

# 4. Start
mix phx.server

# 5. Test
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "Hello!", "session_id": "test"}'
```

---

## 🔧 Troubleshooting

### OpenAI

| Problem | Solution |
|---------|----------|
| `missing_api_key` | Set `OPENAI_API_KEY` in `.env` |
| `Authentication failed` | Check if the API key is correct |
| `Model not found` | Use a valid model: `gpt-4`, `gpt-3.5-turbo` |
| `Rate limit exceeded` | Wait or switch to Ollama temporarily |

### Ollama

| Problem | Solution |
|---------|----------|
| `Connection refused` | Check if Ollama is running: `ollama serve` |
| `Model not found` | Download the model: `ollama pull llama2` |
| `Out of memory` | Use smaller model: `llama2:7b` instead of `llama2:70b` |

### Configuration

| Problem | Solution |
|---------|----------|
| Configuration not loading | Restart the server: `mix phx.server` |
| Wrong provider | Check `LLM_PROVIDER` in `.env` |
| Model not found | Check `*_DEFAULT_MODEL` in `.env` |

---

## 📚 Next Steps

1. **Configure your `.env`** with preferred provider
2. **Test both providers** to compare performance
3. **Adjust parameters** like temperature and max_tokens
4. **Configure cache and RAG** for better performance
5. **Monitor metrics** via health endpoints

---

**🎉 NeuralBridge is configured! Use `mix phx.server` and start making requests.**