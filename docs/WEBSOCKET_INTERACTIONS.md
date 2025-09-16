# NeuralBridge - WebSocket Interactions

## 🔌 WebSocket Real-time Communication

### Connection Setup

#### 1. Client Connection
```javascript
import {Socket} from "phoenix"

// Connect to socket
const socket = new Socket("ws://localhost:4000/socket", {
  params: {
    user_id: "user_456",
    auth_token: "optional_jwt_token"
  }
})

socket.connect()

// Join conversation channel
const channel = socket.channel("proxy:user_session_123", {
  user_id: "user_456"
})

channel.join()
  .receive("ok", resp => console.log("Connected!", resp))
  .receive("error", resp => console.log("Connection error", resp))
```

---

## 💬 Message Interactions

### 2. Standard Query Processing

#### Send Query
```javascript
channel.push("query", {
  query: "How to implement JWT authentication?",
  model: "gpt-4",
  temperature: 0.7,
  metadata: {
    context_type: "programming"
  }
})
```

#### Receive Response
```javascript
channel.on("response", payload => {
  console.log("Response:", payload.response)
  console.log("Metadata:", payload.metadata)
  console.log("Timestamp:", payload.timestamp)
})

// Example received payload:
{
  "response": "To implement JWT authentication in Node.js...",
  "metadata": {
    "source": "llm",
    "confidence_score": 0.89,
    "processing_time_ms": 1250,
    "rag_context_used": 3,
    "model_used": "gpt-4"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 3. Streaming Responses

#### Start Streaming Query
```javascript
channel.push("stream_query", {
  query: "Explain machine learning in detail",
  model: "gpt-4-turbo",
  temperature: 0.6
})
```

#### Handle Streaming Events
```javascript
// Stream start
channel.on("stream_start", payload => {
  console.log("Starting stream for:", payload.query)
  console.log("Timestamp:", payload.timestamp)

  // Clear response area
  document.getElementById("response").innerHTML = ""
})

// Tokens arriving in real time
channel.on("stream_token", payload => {
  const responseArea = document.getElementById("response")
  responseArea.innerHTML += payload.token

  // Auto-scroll to follow
  responseArea.scrollTop = responseArea.scrollHeight
})

// Stream completed
channel.on("stream_complete", () => {
  console.log("Stream finished")

  // Enable new query
  document.getElementById("send-button").disabled = false
})

// Stream error
channel.on("stream_error", payload => {
  console.error("Stream error:", payload.error)

  // Show error message
  document.getElementById("error").textContent = payload.error
})
```

---

## 📚 Conversation Management

### 4. Get Conversation History

#### Request History
```javascript
channel.push("get_history")
```

#### Receive History
```javascript
channel.on("history", payload => {
  const messages = payload.messages

  messages.forEach(message => {
    displayMessage(message.role, message.content, message.timestamp)
  })
})

function displayMessage(role, content, timestamp) {
  const messagesContainer = document.getElementById("messages")
  const messageDiv = document.createElement("div")
  messageDiv.className = `message ${role}`
  messageDiv.innerHTML = `
    <div class="role">${role}</div>
    <div class="content">${content}</div>
    <div class="timestamp">${new Date(timestamp).toLocaleString()}</div>
  `
  messagesContainer.appendChild(messageDiv)
}
```

---

## 🔄 Connection Management

### 5. Ping/Pong Heartbeat

#### Send Ping
```javascript
// Heartbeat to keep connection alive
setInterval(() => {
  channel.push("ping")
}, 30000) // Every 30 seconds
```

#### Handle Pong
```javascript
channel.on("pong", payload => {
  console.log("Pong received:", payload.timestamp)

  // Update connectivity indicator
  document.getElementById("status").textContent = "Connected"
  document.getElementById("status").className = "online"
})
```

### 6. Error Handling

#### Handle General Errors
```javascript
channel.on("error", payload => {
  console.error("Erro:", payload.error)
  console.error("Mensagem:", payload.message)

  // Mostrar notificação de erro
  showNotification("Erro: " + payload.message, "error")

  // Desabilitar interface temporariamente
  if (payload.error === "processing_failed") {
    disableInterface(5000) // 5 segundos
  }
})
```

#### Connection State Management
```javascript
channel.onError(() => {
  console.log("Erro na conexão do canal")
  document.getElementById("status").textContent = "Erro de Conexão"
  document.getElementById("status").className = "error"
})

channel.onClose(() => {
  console.log("Canal fechado")
  document.getElementById("status").textContent = "Desconectado"
  document.getElementById("status").className = "offline"

  // Tentar reconectar após 5 segundos
  setTimeout(() => {
    channel.join()
  }, 5000)
})
```

---

## 🎨 Complete Frontend Example

### 7. Full Implementation

```html
<!DOCTYPE html>
<html>
<head>
  <title>NeuralBridge Chat</title>
  <style>
    .chat-container { max-width: 800px; margin: 0 auto; }
    .messages { height: 400px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; }
    .message { margin: 10px 0; padding: 10px; border-radius: 5px; }
    .message.user { background: #e3f2fd; margin-left: 20%; }
    .message.assistant { background: #f3e5f5; margin-right: 20%; }
    .input-area { display: flex; margin-top: 10px; }
    .input-area input { flex: 1; padding: 10px; }
    .input-area button { padding: 10px 20px; }
    .status { text-align: center; margin: 10px 0; }
    .status.online { color: green; }
    .status.error { color: red; }
    .status.offline { color: gray; }
    .streaming { opacity: 0.7; }
  </style>
</head>
<body>
  <div class="chat-container">
    <div id="status" class="status offline">Conectando...</div>

    <div id="messages" class="messages"></div>

    <div class="input-area">
      <input
        type="text"
        id="message-input"
        placeholder="Digite sua mensagem..."
        onkeypress="handleKeyPress(event)"
      >
      <button id="send-button" onclick="sendMessage()">Enviar</button>
      <button onclick="toggleStreaming()">
        <span id="streaming-mode">Stream: OFF</span>
      </button>
    </div>

    <div id="error" style="color: red; margin-top: 10px;"></div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.0/priv/static/phoenix.js"></script>
  <script>
    let isStreaming = false
    let currentResponse = ""

    // Configuração do socket
    const socket = new Phoenix.Socket("ws://localhost:4000/socket")
    socket.connect()

    // Canal da conversa
    const sessionId = "session_" + Math.random().toString(36).substr(2, 9)
    const channel = socket.channel(`proxy:${sessionId}`, {
      user_id: "user_123"
    })

    // Eventos de conexão
    channel.join()
      .receive("ok", resp => {
        console.log("Conectado!", resp)
        document.getElementById("status").textContent = "Conectado"
        document.getElementById("status").className = "status online"
      })
      .receive("error", resp => {
        console.log("Erro na conexão", resp)
        document.getElementById("status").textContent = "Erro de Conexão"
        document.getElementById("status").className = "status error"
      })

    // Resposta padrão
    channel.on("response", payload => {
      addMessage("assistant", payload.response, payload.metadata)
      enableInput()
    })

    // Streaming
    channel.on("stream_start", payload => {
      console.log("Stream iniciado para:", payload.query)
      currentResponse = ""
      addStreamingMessage("assistant")
    })

    channel.on("stream_token", payload => {
      currentResponse += payload.token
      updateStreamingMessage(currentResponse)
    })

    channel.on("stream_complete", () => {
      finalizeStreamingMessage()
      enableInput()
    })

    // Erros
    channel.on("error", payload => {
      document.getElementById("error").textContent = payload.message
      enableInput()
    })

    channel.on("stream_error", payload => {
      document.getElementById("error").textContent = payload.error
      enableInput()
    })

    // Funções de interface
    function sendMessage() {
      const input = document.getElementById("message-input")
      const message = input.value.trim()

      if (!message) return

      addMessage("user", message)
      input.value = ""
      disableInput()

      if (isStreaming) {
        channel.push("stream_query", { query: message })
      } else {
        channel.push("query", { query: message })
      }
    }

    function addMessage(role, content, metadata = null) {
      const messagesDiv = document.getElementById("messages")
      const messageDiv = document.createElement("div")
      messageDiv.className = `message ${role}`

      let metadataHtml = ""
      if (metadata) {
        metadataHtml = `
          <div style="font-size: 0.8em; color: #666; margin-top: 5px;">
            Fonte: ${metadata.source} |
            Confiança: ${(metadata.confidence_score * 100).toFixed(1)}% |
            Tempo: ${metadata.processing_time_ms}ms
          </div>
        `
      }

      messageDiv.innerHTML = `
        <div>${content}</div>
        ${metadataHtml}
      `

      messagesDiv.appendChild(messageDiv)
      messagesDiv.scrollTop = messagesDiv.scrollHeight
    }

    function addStreamingMessage(role) {
      const messagesDiv = document.getElementById("messages")
      const messageDiv = document.createElement("div")
      messageDiv.className = `message ${role} streaming`
      messageDiv.id = "streaming-message"
      messageDiv.innerHTML = "<div></div>"

      messagesDiv.appendChild(messageDiv)
      messagesDiv.scrollTop = messagesDiv.scrollHeight
    }

    function updateStreamingMessage(content) {
      const streamingDiv = document.getElementById("streaming-message")
      if (streamingDiv) {
        streamingDiv.querySelector("div").textContent = content
        document.getElementById("messages").scrollTop =
          document.getElementById("messages").scrollHeight
      }
    }

    function finalizeStreamingMessage() {
      const streamingDiv = document.getElementById("streaming-message")
      if (streamingDiv) {
        streamingDiv.classList.remove("streaming")
        streamingDiv.id = ""
      }
    }

    function disableInput() {
      document.getElementById("send-button").disabled = true
      document.getElementById("message-input").disabled = true
    }

    function enableInput() {
      document.getElementById("send-button").disabled = false
      document.getElementById("message-input").disabled = false
      document.getElementById("message-input").focus()
    }

    function toggleStreaming() {
      isStreaming = !isStreaming
      const streamingSpan = document.getElementById("streaming-mode")
      streamingSpan.textContent = `Stream: ${isStreaming ? "ON" : "OFF"}`
    }

    function handleKeyPress(event) {
      if (event.key === "Enter") {
        sendMessage()
      }
    }

    // Heartbeat
    setInterval(() => {
      channel.push("ping")
    }, 30000)

    channel.on("pong", () => {
      console.log("Pong recebido")
    })
  </script>
</body>
</html>
```

---

## 📱 React/Vue.js Integration

### 8. React Hook Example

```javascript
import { useEffect, useState } from 'react'
import { Socket } from 'phoenix'

export function useNeuralBridge(sessionId, userId) {
  const [socket, setSocket] = useState(null)
  const [channel, setChannel] = useState(null)
  const [connected, setConnected] = useState(false)
  const [messages, setMessages] = useState([])
  const [isStreaming, setIsStreaming] = useState(false)

  useEffect(() => {
    const newSocket = new Socket("ws://localhost:4000/socket", {
      params: { user_id: userId }
    })

    newSocket.connect()
    setSocket(newSocket)

    const newChannel = newSocket.channel(`proxy:${sessionId}`, {
      user_id: userId
    })

    newChannel.join()
      .receive("ok", () => setConnected(true))
      .receive("error", () => setConnected(false))

    // Event listeners
    newChannel.on("response", (payload) => {
      setMessages(prev => [...prev, {
        role: "assistant",
        content: payload.response,
        metadata: payload.metadata,
        timestamp: payload.timestamp
      }])
    })

    newChannel.on("stream_token", (payload) => {
      setMessages(prev => {
        const updated = [...prev]
        const lastMessage = updated[updated.length - 1]
        if (lastMessage && lastMessage.streaming) {
          lastMessage.content += payload.token
        }
        return updated
      })
    })

    setChannel(newChannel)

    return () => {
      newChannel.leave()
      newSocket.disconnect()
    }
  }, [sessionId, userId])

  const sendMessage = (query, options = {}) => {
    if (!channel || !connected) return

    // Adicionar mensagem do usuário
    setMessages(prev => [...prev, {
      role: "user",
      content: query,
      timestamp: new Date().toISOString()
    }])

    if (options.streaming) {
      // Adicionar placeholder para streaming
      setMessages(prev => [...prev, {
        role: "assistant",
        content: "",
        streaming: true,
        timestamp: new Date().toISOString()
      }])

      channel.push("stream_query", { query, ...options })
    } else {
      channel.push("query", { query, ...options })
    }
  }

  return {
    connected,
    messages,
    sendMessage,
    isStreaming,
    setIsStreaming
  }
}
```

---

## 🔧 Advanced Features

### 9. Message Types & Events

#### Complete Event Reference
```javascript
// Outgoing events (cliente → servidor)
channel.push("query", { query, model, temperature })
channel.push("stream_query", { query, model, temperature })
channel.push("get_history")
channel.push("ping")

// Incoming events (servidor → cliente)
channel.on("response", payload => {})      // Resposta completa
channel.on("stream_start", payload => {}) // Início do streaming
channel.on("stream_token", payload => {}) // Token individual
channel.on("stream_complete", () => {})   // Fim do streaming
channel.on("stream_error", payload => {}) // Erro no streaming
channel.on("history", payload => {})      // Histórico da conversa
channel.on("pong", payload => {})         // Resposta do ping
channel.on("error", payload => {})        // Erro geral
```

### 10. Connection Resilience

```javascript
// Reconexão automática
function setupResilience(channel) {
  let reconnectTimer = null

  channel.onError(() => {
    console.log("Erro no canal, tentando reconectar...")
    attemptReconnect()
  })

  channel.onClose(() => {
    console.log("Canal fechado, tentando reconectar...")
    attemptReconnect()
  })

  function attemptReconnect() {
    if (reconnectTimer) return

    reconnectTimer = setTimeout(() => {
      channel.join()
        .receive("ok", () => {
          console.log("Reconectado com sucesso!")
          reconnectTimer = null
        })
        .receive("error", () => {
          reconnectTimer = null
          attemptReconnect() // Tentar novamente
        })
    }, 2000) // Tentar a cada 2 segundos
  }
}
```

Essa documentação cobre todas as interações WebSocket possíveis com o NeuralBridge, incluindo exemplos práticos de implementação! 🚀