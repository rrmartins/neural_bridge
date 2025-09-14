# 🚀 NeuralBridge - Quick Setup

## ⚡ Configuration in 3 Steps

### 1️⃣ Clone and Configure

```bash
# Clone the project
git clone <repository-url>
cd neural_bridge

# Install dependencies
mix setup
mix ecto.create
mix ecto.migrate
```

### 2️⃣ Configure your LLM Provider

**Option A - OpenAI:**
```bash
echo "LLM_PROVIDER=openai" > .env
echo "OPENAI_API_KEY=sk-your-key-here" >> .env
echo "OPENAI_DEFAULT_MODEL=gpt-4" >> .env
```

**Option B - Ollama:**
```bash
# Install Ollama first
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama2

# Configure .env
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env
```

### 3️⃣ Run and Test

```bash
# Start the server
mix phx.server

# Test the configuration
curl http://localhost:4000/api/proxy/health

# Ask a question
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Hello, how are you?",
    "session_id": "test_123"
  }'
```

## 🔧 Advanced Configuration

For complete configuration, see:
- [CONFIG_GUIDE.md](CONFIG_GUIDE.md) - Detailed configuration guide
- [../.env.example](../.env.example) - All available options

## 🤖 Provider Switch

```bash
# To switch from OpenAI to Ollama
sed -i 's/LLM_PROVIDER=openai/LLM_PROVIDER=ollama/' .env

# Restart the server
mix phx.server
```

## ✅ Verification

- ✅ Server running at `http://localhost:4000`
- ✅ Health check working
- ✅ API responding with configured provider
- ✅ Cache, RAG and Guardrails active

**🎉 Ready! Your LLM proxy is working.**