# 🧠 NeuralBridge - Proxy LLM Inteligente

> **Proxy avançado entre aplicações e provedores de LLM com configuração via .env**

NeuralBridge é um proxy inteligente que atua como intermediário entre suas aplicações e diferentes provedores de LLM (OpenAI, Ollama), implementando cache inteligente, RAG (Retrieval-Augmented Generation), guardrails de segurança e fallback automático. Configure facilmente via variáveis de ambiente qual provedor usar como padrão.

## ✨ Características Principais

- ⚙️ **Configuração .env** - Defina o provedor padrão (OpenAI/Ollama) via variáveis de ambiente
- 🔄 **Pipeline Inteligente** - Cache → RAG → LLM → API B (fallback)
- 🤖 **Multi-Provider** - OpenAI e Ollama com modelos configuráveis
- 🧠 **RAG Integrado** - Busca semântica em base de conhecimento
- 🛡️ **Guardrails** - Validação de segurança e qualidade
- 📊 **Observabilidade** - Métricas em tempo real e telemetria
- 🔄 **Background Jobs** - Processamento assíncrono de embeddings e treinamento
- 💾 **Cache Híbrido** - Memória + PostgreSQL persistente
- 🌐 **WebSockets** - Streaming de respostas em tempo real

## 🚀 Início Rápido

### 1. Instalação

```bash
# Clone o repositório
git clone <repository-url>
cd neural_bridge

# Instale dependências
mix setup

# Configure o banco de dados
mix ecto.create
mix ecto.migrate
```

### 2. Configuração (.env)

**Opção 1 - OpenAI:**
```bash
# Copie o arquivo de exemplo
cp .env.example .env

# Configure para OpenAI
echo "LLM_PROVIDER=openai" > .env
echo "OPENAI_API_KEY=sk-your-key-here" >> .env
echo "OPENAI_DEFAULT_MODEL=gpt-4" >> .env
```

**Opção 2 - Ollama:**
```bash
# Instale Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Baixe modelos
ollama pull llama2

# Configure para Ollama
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env
```

### 3. Execução

```bash
# Inicie o servidor
mix phx.server

# Teste a configuração
curl http://localhost:4000/api/proxy/health
```

## 🔧 Configuração via .env

O NeuralBridge usa variáveis de ambiente para determinar automaticamente qual provedor LLM usar:

### Arquivo .env exemplo:

```bash
# Provedor principal (openai ou ollama)
LLM_PROVIDER=ollama

# Configuração OpenAI
OPENAI_API_KEY=sk-your-key-here
OPENAI_DEFAULT_MODEL=gpt-4
OPENAI_DEFAULT_TEMPERATURE=0.7

# Configuração Ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2

# Cache e outras configurações
CACHE_ENABLED=true
CACHE_TTL_SECONDS=3600
```

### Modelos Suportados:

**OpenAI:** `gpt-4`, `gpt-4-turbo`, `gpt-3.5-turbo`

**Ollama:** `llama2`, `codellama`, `mistral`, `neural-chat`, modelos personalizados (`llama2:7b-chat`)

## 📡 API REST

### Endpoint Principal

```bash
# Usa configuração padrão do .env
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Explique machine learning",
    "session_id": "minha_sessao_123"
  }'

# Override do provedor na requisição
curl -X POST "http://localhost:4000/api/proxy/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Explique machine learning",
    "session_id": "minha_sessao_123",
    "provider": "openai",
    "model": "gpt-4"
  }'
```

### Endpoints de Monitoramento

```bash
# Verificar saúde
curl http://localhost:4000/api/proxy/health

# Obter estatísticas
curl http://localhost:4000/api/proxy/stats
```

## 🔄 Pipeline de Processamento

```
1. 💾 Cache Check → Resposta instantânea se encontrada
2. 🧠 RAG Retrieval → Busca contexto na base de conhecimento
3. 🤖 LLM Generation → OpenAI ou Ollama
4. 🛡️ Guardrails → Validação de segurança
5. 🔄 API B Fallback → Fallback automático se necessário
```

## 📊 Observabilidade

- **PromEx Integration** - Métricas Prometheus
- **Real-time Stats** - Interface web com métricas ao vivo
- **Health Checks** - Monitoramento de todos os componentes
- **Telemetry Events** - Rastreamento detalhado de operações

## 🔧 Arquitetura

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

### Componentes Principais:

- **ConversationServer** - GenServer para gestão de sessões
- **Cache** - Sistema híbrido Cachex + PostgreSQL
- **RAG** - Retrieval-Augmented Generation com embeddings
- **LLM** - Cliente unificado OpenAI/Ollama
- **Guardrails** - Validação de segurança e qualidade
- **Background Jobs** - Oban para processamento assíncrono

## 📚 Documentação

- **[Guia de Configuração](docs/CONFIG_GUIDE.md)** - Setup detalhado OpenAI/Ollama
- **[API Interactions](docs/API_INTERACTIONS.md)** - Documentação completa da API
- **[WebSocket Guide](docs/WEBSOCKET_INTERACTIONS.md)** - Streaming em tempo real
- **[Background Jobs](docs/BACKGROUND_JOBS.md)** - Sistema de jobs assíncronos

## 🛠️ Desenvolvimento

### Estrutura de Arquivos

```
lib/
├── neural_bridge/
│   ├── application.ex          # Supervisor principal
│   ├── conversation_server.ex  # Gestão de sessões
│   ├── cache.ex               # Sistema de cache
│   ├── rag.ex                 # Retrieval-Augmented Generation
│   ├── llm.ex                 # Cliente LLM unificado
│   ├── guardrails.ex          # Validações de segurança
│   └── workers/               # Background jobs
└── neural_bridge_web/
    ├── channels/              # WebSocket channels
    ├── controllers/           # REST controllers
    └── router.ex             # Roteamento
```

### Background Jobs

- **EmbedJob** - Geração de embeddings para RAG
- **TrainJob** - Treinamento de modelos (fine-tuning/distillation)
- **CacheCleanupWorker** - Limpeza automática de cache
- **TrainingDatasetWorker** - Análise e trigger de treinamentos

### Executar Testes

```bash
mix test
```

### Executar em Desenvolvimento

```bash
# Com live reloading
mix phx.server

# No console interativo
iex -S mix phx.server
```

## 📈 Monitoramento em Produção

### Métricas Disponíveis

- Cache hit/miss rates
- Response times por provider
- Confidence scores
- API B fallback rates
- Training job performance
- System resources

### Health Checks

- Database connectivity
- Cache system status
- LLM provider availability
- API B connectivity

## 🔐 Segurança

- **Guardrails** automáticos para validação de conteúdo
- **PII Detection** e remoção
- **Rate limiting** por sessão
- **Input sanitization**
- **Secure session management**

## 🚀 Deploy em Produção

```bash
# Build release
MIX_ENV=prod mix release

# Execute
_build/prod/rel/neural_bridge/bin/neural_bridge start
```

### Variáveis de Ambiente

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

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma feature branch (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🔗 Links Úteis

- **Phoenix Framework**: https://www.phoenixframework.org/
- **OpenAI API**: https://platform.openai.com/docs
- **Ollama**: https://ollama.com/
- **Oban**: https://github.com/sorentwo/oban
- **PromEx**: https://github.com/akoutmos/prom_ex

---

**🎉 Comece agora: `mix phx.server` e acesse `http://localhost:4000`**