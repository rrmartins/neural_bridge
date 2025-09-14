# NeuralBridge - API Interactions

## 📡 REST API Interactions

### 1. Query Processing

#### POST /api/proxy/query
Endpoint principal para processamento de queries com fallback inteligente.

**Request:**
```json
{
  "query": "Como implementar autenticação JWT em Node.js?",
  "session_id": "user_session_123",
  "user_id": "user_456",
  "model": "gpt-4",
  "temperature": 0.7,
  "streaming": false
}
```

**Response (Success):**
```json
{
  "success": true,
  "response": "Para implementar autenticação JWT em Node.js...",
  "metadata": {
    "source": "llm",
    "confidence_score": 0.89,
    "processing_time_ms": 1250,
    "rag_context_used": 3,
    "model_used": "gpt-4"
  },
  "session_id": "user_session_123"
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Processing failed",
  "message": "Unable to process query at this time"
}
```

**Pipeline de Decisão:**
1. **Cache Check** → Se encontrado, retorna imediatamente
2. **RAG Retrieval** → Busca contexto semântico
3. **LLM Generation** → Gera resposta com confiança
4. **Validation** → Aplica guardrails
5. **API B Fallback** → Se confiança < 0.7

---

### 2. Health Monitoring

#### GET /api/proxy/health
Verifica saúde de todos os componentes do sistema.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "checks": {
    "cache": "ok",
    "database": "ok",
    "llm_openai": "ok",
    "llm_ollama": "error",
    "api_b": "ok"
  }
}
```

**Componentes Verificados:**
- Cache (Cachex) accessibility
- Database connection
- OpenAI API connectivity
- Ollama service availability
- External API B health

---

### 3. System Statistics

#### GET /api/proxy/stats
Retorna estatísticas detalhadas do sistema.

**Response:**
```json
{
  "cache": {
    "size": 1847,
    "detailed_stats": {
      "hit_rate": 0.73,
      "miss_rate": 0.27,
      "memory_usage": 15728640,
      "persistent_active_entries": 892
    }
  },
  "conversations": {
    "active_conversations": 23
  },
  "system": {
    "memory_usage": {
      "total": 41943040,
      "processes": 28311552,
      "atom": 1049624
    },
    "process_count": 342,
    "uptime_seconds": 7245
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 💬 Conversation Management

### 4. Get Conversation

#### GET /api/conversations/:session_id
Retorna informações da conversa.

**Response:**
```json
{
  "conversation": {
    "id": "conv_uuid_123",
    "session_id": "user_session_123",
    "user_id": "user_456",
    "title": "Discussão sobre JWT",
    "last_activity_at": "2024-01-15T10:25:00Z",
    "message_count": 8
  }
}
```

### 5. Get Conversation History

#### GET /api/conversations/:session_id/history
Retorna histórico completo da conversa.

**Response:**
```json
{
  "messages": [
    {
      "id": "msg_uuid_1",
      "role": "user",
      "content": "Como implementar JWT?",
      "timestamp": "2024-01-15T10:20:00Z",
      "metadata": {}
    },
    {
      "id": "msg_uuid_2",
      "role": "assistant",
      "content": "Para implementar JWT...",
      "timestamp": "2024-01-15T10:20:15Z",
      "metadata": {
        "source": "llm",
        "confidence_score": 0.89,
        "processing_time_ms": 1250
      }
    }
  ],
  "total_messages": 8
}
```

---

## 🧠 Knowledge Management

### 6. Document Ingestion

#### POST /api/knowledge/ingest
Ingere documentos para a base de conhecimento RAG.

**Request:**
```json
{
  "content": "JWT (JSON Web Token) é um padrão...",
  "source_document": "jwt_guide.pdf",
  "metadata": {
    "author": "Tech Team",
    "category": "authentication",
    "version": "1.2"
  }
}
```

**Response:**
```json
{
  "success": true,
  "chunks_created": 12,
  "document_id": "jwt_guide.pdf",
  "processing_job_id": "embed_job_456"
}
```

### 7. List Documents

#### GET /api/knowledge/documents
Lista todos os documentos na base de conhecimento.

**Response:**
```json
{
  "documents": [
    {
      "source_document": "jwt_guide.pdf",
      "chunk_count": 12,
      "last_processed": "2024-01-15T09:30:00Z",
      "total_content_length": 15420
    },
    {
      "source_document": "node_auth.md",
      "chunk_count": 8,
      "last_processed": "2024-01-14T16:20:00Z",
      "total_content_length": 9876
    }
  ],
  "total_documents": 2
}
```

---

## 🎓 Training Management

### 8. Create Training Job

#### POST /api/training/jobs
Cria job de treinamento (fine-tuning ou distillation).

**Request:**
```json
{
  "job_type": "fine_tune",
  "config": {
    "dataset_limit": 1000,
    "learning_rate": 0.0001,
    "epochs": 3,
    "model_name": "neural-bridge-ft-v1"
  }
}
```

**Response:**
```json
{
  "job_id": "train_job_789",
  "status": "pending",
  "estimated_duration_minutes": 45,
  "queue_position": 2
}
```

### 9. Training Job Status

#### GET /api/training/jobs/:job_id
Acompanha progresso do job de treinamento.

**Response:**
```json
{
  "job": {
    "id": "train_job_789",
    "status": "running",
    "job_type": "fine_tune",
    "progress_percentage": 65.5,
    "started_at": "2024-01-15T10:00:00Z",
    "estimated_completion": "2024-01-15T10:45:00Z",
    "dataset_size": 1000,
    "current_epoch": 2,
    "training_loss": 0.23,
    "validation_loss": 0.28
  }
}
```

---

## 🗄️ Cache Management

### 10. Cache Statistics

#### GET /api/cache/stats
Estatísticas detalhadas do sistema de cache.

**Response:**
```json
{
  "memory_cache": {
    "size": 1847,
    "hit_rate": 0.73,
    "memory_usage_bytes": 15728640,
    "evictions": 234
  },
  "persistent_cache": {
    "total_entries": 4521,
    "active_entries": 3892,
    "expired_entries": 629,
    "total_hits": 15673,
    "avg_hit_count": 3.47
  },
  "performance": {
    "avg_retrieval_time_ms": 12,
    "cache_efficiency": 0.78
  }
}
```

### 11. Clear Cache

#### DELETE /api/cache
Limpa todo o cache (memória + persistente).

**Response:**
```json
{
  "success": true,
  "message": "Cache cleared successfully",
  "entries_removed": {
    "memory": 1847,
    "persistent": 3892
  }
}
```

---

## 🔧 Admin Operations

### 12. System Information

#### GET /api/admin/system
Informações detalhadas do sistema para administradores.

**Response:**
```json
{
  "system": {
    "elixir_version": "1.18.4",
    "otp_version": "26",
    "neural_bridge_version": "1.0.0",
    "uptime_seconds": 7245,
    "node_name": "neural_bridge@localhost"
  },
  "database": {
    "connection_pool_size": 10,
    "active_connections": 3,
    "total_queries": 15420,
    "avg_query_time_ms": 45
  },
  "background_jobs": {
    "total_jobs": 1205,
    "completed": 1198,
    "failed": 7,
    "queues": {
      "default": 2,
      "embeddings": 0,
      "training": 1
    }
  }
}
```

### 13. Metrics Export

#### GET /api/admin/metrics
Exporta métricas em formato Prometheus.

**Response (text/plain):**
```
# HELP neural_bridge_queries_total Total queries processed
# TYPE neural_bridge_queries_total counter
neural_bridge_queries_total{source="cache",status="success"} 1247
neural_bridge_queries_total{source="llm",status="success"} 892
neural_bridge_queries_total{source="api_b",status="success"} 156

# HELP neural_bridge_cache_hit_rate Cache hit rate percentage
# TYPE neural_bridge_cache_hit_rate histogram
neural_bridge_cache_hit_rate_bucket{le="0.5"} 23
neural_bridge_cache_hit_rate_bucket{le="0.7"} 45
neural_bridge_cache_hit_rate_bucket{le="0.9"} 78
```

---

## 🚨 Error Responses

### Standard Error Format
```json
{
  "success": false,
  "error": "error_code",
  "message": "Human readable message",
  "details": {
    "field": "Additional context",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### Common Error Codes
- `invalid_params` - Parâmetros obrigatórios ausentes
- `processing_failed` - Erro interno de processamento
- `rate_limited` - Limite de taxa excedido
- `unauthorized` - Token de autenticação inválido
- `service_unavailable` - Serviço temporariamente indisponível
- `validation_failed` - Falha na validação de guardrails