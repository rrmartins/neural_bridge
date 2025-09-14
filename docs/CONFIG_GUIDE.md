# 🔧 NeuralBridge - Guia de Configuração (.env)

## 🎯 Visão Geral

Este guia explica como configurar o NeuralBridge usando variáveis de ambiente (`.env`) para determinar automaticamente qual provedor LLM usar (OpenAI ou Ollama) e personalizar todas as configurações do sistema.

---

## 📁 Configuração Básica

### 1. Copie o arquivo de exemplo

```bash
cp .env.example .env
```

### 2. Configure seu provedor principal

O NeuralBridge automaticamente usa o provedor definido em `LLM_PROVIDER`:

```bash
# Para usar OpenAI como padrão
LLM_PROVIDER=openai

# Para usar Ollama como padrão
LLM_PROVIDER=ollama
```

---

## 🤖 Configuração OpenAI

Para usar OpenAI como provedor principal, configure:

```bash
# Provedor principal
LLM_PROVIDER=openai

# Chave da API (obtenha em: https://platform.openai.com/api-keys)
OPENAI_API_KEY=sk-your-openai-api-key-here

# Configurações opcionais
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7
OPENAI_MAX_TOKENS=2048
```

### Modelos OpenAI Disponíveis:
- `gpt-4` - Mais inteligente
- `gpt-4-turbo` - Velocidade otimizada
- `gpt-3.5-turbo` - Custo-benefício

### Exemplo completo para OpenAI:

```bash
# .env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-abc123...
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7
```

---

## 🦙 Configuração Ollama

Para usar Ollama como provedor principal:

### 1. Instale o Ollama

```bash
# macOS/Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows: baixe de https://ollama.com/download
```

### 2. Baixe modelos

```bash
ollama pull llama2
ollama pull codellama
ollama pull mistral
ollama pull neural-chat
```

### 3. Configure o .env

```bash
# Provedor principal
LLM_PROVIDER=ollama

# URL do Ollama (padrão: localhost:11434)
OLLAMA_BASE_URL=http://localhost:11434

# Modelo padrão
OLLAMA_DEFAULT_MODEL=llama2
```

### Modelos Ollama Suportados:
- `llama2` - Modelo geral robusto
- `codellama` - Especializado em código
- `mistral` - Modelo eficiente europeu
- `neural-chat` - Otimizado para conversas
- Modelos personalizados: `llama2:7b-chat`, `llama2:13b-chat`, etc.

### Exemplo completo para Ollama:

```bash
# .env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=codellama
```

---

## 🔄 Mudança Dinâmica de Provedor

### Via Variável de Ambiente

```bash
# Usar OpenAI
export LLM_PROVIDER=openai
mix phx.server

# Usar Ollama
export LLM_PROVIDER=ollama
mix phx.server
```

### Via API (override por requisição)

Mesmo com um provedor padrão configurado, você pode especificar outro na requisição:

```bash
# Servidor configurado para Ollama, mas usando OpenAI nesta chamada
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Explique machine learning",
    "session_id": "test_123",
    "provider": "openai",
    "model": "gpt-4"
  }'
```

---

## 📋 Arquivo .env Completo

Aqui está um exemplo completo de `.env` com todas as opções:

```bash
# ================================
# NeuralBridge - Configuração LLM
# ================================

# =====================
# Provedor Principal
# =====================
LLM_PROVIDER=ollama

# =====================
# Configuração OpenAI
# =====================
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7
OPENAI_MAX_TOKENS=2048

# =====================
# Configuração Ollama
# =====================
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2

# =====================
# API B (Fallback)
# =====================
API_B_ENABLED=true
API_B_URL=https://api.exemplo.com/v1/chat
API_B_TOKEN=seu-token-api-b-aqui
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

## 🧪 Testando a Configuração

### 1. Verificar configuração atual

```bash
# Testar saúde do sistema
curl http://localhost:4000/api/proxy/health

# Ver estatísticas
curl http://localhost:4000/api/proxy/stats
```

### 2. Teste com provedor padrão

```bash
# Usar configuração padrão do .env
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Olá, como você está?",
    "session_id": "test_session_123"
  }'
```

### 3. Teste com provedor específico

```bash
# Forçar uso de OpenAI (mesmo se Ollama for padrão)
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Qual é a capital do Brasil?",
    "session_id": "test_session_456",
    "provider": "openai",
    "model": "gpt-3.5-turbo"
  }'
```

---

## 🔄 Cenários de Uso Comuns

### Desenvolvimento com Ollama

```bash
# .env para desenvolvimento local
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2
CACHE_ENABLED=true
DEBUG_MODE=true
LOG_LEVEL=debug
```

### Produção com OpenAI

```bash
# .env para produção
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-prod-key-here
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_MAX_TOKENS=4096
CACHE_ENABLED=true
CACHE_TTL_SECONDS=7200
GUARDRAILS_ENABLED=true
PROM_EX_ENABLED=true
```

### Ambiente Híbrido

```bash
# OpenAI como padrão, Ollama disponível para override
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-key-here
OPENAI_DEFAULT_MODEL=gpt-4

# Ollama também configurado
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=codellama

# Fallback robusto
API_B_ENABLED=true
API_B_URL=https://backup-api.com/v1/chat
API_B_TOKEN=backup-token
```

---

## 🚀 Inicialização Rápida

### Para OpenAI:

```bash
# 1. Configure
echo "LLM_PROVIDER=openai" > .env
echo "OPENAI_API_KEY=sk-your-key-here" >> .env

# 2. Inicie
mix phx.server

# 3. Teste
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "Olá!", "session_id": "test"}'
```

### Para Ollama:

```bash
# 1. Instale Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Baixe modelo
ollama pull llama2

# 3. Configure
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env

# 4. Inicie
mix phx.server

# 5. Teste
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "Olá!", "session_id": "test"}'
```

---

## 🔧 Solução de Problemas

### OpenAI

| Problema | Solução |
|----------|---------|
| `missing_api_key` | Defina `OPENAI_API_KEY` no `.env` |
| `Authentication failed` | Verifique se a chave da API está correta |
| `Model not found` | Use um modelo válido: `gpt-4`, `gpt-3.5-turbo` |
| `Rate limit exceeded` | Aguarde ou mude para Ollama temporariamente |

### Ollama

| Problema | Solução |
|----------|---------|
| `Connection refused` | Verifique se Ollama está rodando: `ollama serve` |
| `Model not found` | Baixe o modelo: `ollama pull llama2` |
| `Out of memory` | Use modelo menor: `llama2:7b` em vez de `llama2:70b` |

### Configuração

| Problema | Solução |
|----------|---------|
| Configuração não carrega | Reinicie o servidor: `mix phx.server` |
| Provedor errado | Verifique `LLM_PROVIDER` no `.env` |
| Modelo não encontrado | Verifique `*_DEFAULT_MODEL` no `.env` |

---

## 📚 Próximos Passos

1. **Configure seu `.env`** com o provedor preferido
2. **Teste ambos os provedores** para comparar performance
3. **Ajuste parâmetros** como temperatura e max_tokens
4. **Configure cache e RAG** para melhor performance
5. **Monitore métricas** via endpoints de saúde

---

**🎉 O NeuralBridge está configurado! Use `mix phx.server` e comece a fazer requisições.**