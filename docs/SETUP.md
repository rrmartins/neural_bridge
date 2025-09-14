# 🚀 NeuralBridge - Setup Rápido

## ⚡ Configuração em 3 Passos

### 1️⃣ Clone e Configure

```bash
# Clone o projeto
git clone <repository-url>
cd neural_bridge

# Instale dependências
mix setup
mix ecto.create
mix ecto.migrate
```

### 2️⃣ Configure seu Provedor LLM

**Opção A - OpenAI:**
```bash
echo "LLM_PROVIDER=openai" > .env
echo "OPENAI_API_KEY=sk-your-key-here" >> .env
echo "OPENAI_DEFAULT_MODEL=gpt-4" >> .env
```

**Opção B - Ollama:**
```bash
# Instale Ollama primeiro
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama2

# Configure .env
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env
```

### 3️⃣ Execute e Teste

```bash
# Inicie o servidor
mix phx.server

# Teste a configuração
curl http://localhost:4000/api/proxy/health

# Faça uma pergunta
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Olá, como você está?",
    "session_id": "test_123"
  }'
```

## 🔧 Configuração Avançada

Para configuração completa, veja:
- [CONFIG_GUIDE.md](docs/CONFIG_GUIDE.md) - Guia detalhado de configuração
- [.env.example](.env.example) - Todas as opções disponíveis

## 🤖 Mudança de Provedor

```bash
# Para trocar de OpenAI para Ollama
sed -i 's/LLM_PROVIDER=openai/LLM_PROVIDER=ollama/' .env

# Reinicie o servidor
mix phx.server
```

## ✅ Verificação

- ✅ Servidor rodando em `http://localhost:4000`
- ✅ Health check funcionando
- ✅ API respondendo com provedor configurado
- ✅ Cache, RAG e Guardrails ativos

**🎉 Pronto! Seu proxy LLM está funcionando.**