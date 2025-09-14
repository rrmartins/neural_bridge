defmodule NeuralBridgeWeb.ProxyChannel do
  use NeuralBridgeWeb, :channel

  alias NeuralBridge.ConversationServer
  alias NeuralBridge.Guardrails
  require Logger

  @impl true
  def join("proxy:" <> session_id, payload, socket) do
    if authorized?(payload) do
      user_id = Map.get(payload, "user_id")

      case ConversationServer.get_or_start_conversation(session_id, user_id) do
        {:ok, pid} ->
          socket = assign(socket, :conversation_pid, pid)
          socket = assign(socket, :session_id, session_id)
          socket = assign(socket, :user_id, user_id)

          Logger.info("User connected to proxy channel: #{session_id}")

          {:ok, %{status: "connected", session_id: session_id}, socket}

        {:error, reason} ->
          Logger.error("Failed to start conversation: #{inspect(reason)}")
          {:error, %{reason: "failed_to_start_conversation"}}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("query", %{"query" => query} = payload, socket) do
    session_id = socket.assigns.session_id
    pid = socket.assigns.conversation_pid

    # Validate query
    case Guardrails.validate_query(query) do
      :ok ->
        handle_query(pid, query, payload, socket)

      {:error, reason} ->
        Logger.warning("Query validation failed for session #{session_id}: #{inspect(reason)}")

        push(socket, "error", %{
          error: "invalid_query",
          message: "Query failed validation",
          reason: inspect(reason)
        })

        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("stream_query", %{"query" => query} = payload, socket) do
    session_id = socket.assigns.session_id
    pid = socket.assigns.conversation_pid

    # Validate query
    case Guardrails.validate_query(query) do
      :ok ->
        handle_streaming_query(pid, query, payload, socket)

      {:error, reason} ->
        Logger.warning("Streaming query validation failed for session #{session_id}: #{inspect(reason)}")

        push(socket, "stream_error", %{
          error: "invalid_query",
          message: "Query failed validation",
          reason: inspect(reason)
        })

        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("get_history", _payload, socket) do
    pid = socket.assigns.conversation_pid

    case ConversationServer.get_conversation_history(pid) do
      {:ok, history} ->
        push(socket, "history", %{messages: format_messages(history)})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "error", %{
          error: "failed_to_get_history",
          reason: inspect(reason)
        })

        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    push(socket, "pong", %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
    {:noreply, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("Unhandled channel event: #{event} with payload: #{inspect(payload)}")
    push(socket, "error", %{error: "unknown_event", event: event})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:token, token}, socket) do
    push(socket, "stream_token", %{token: token})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:done}, socket) do
    push(socket, "stream_complete", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:error, reason}, socket) do
    push(socket, "stream_error", %{error: inspect(reason)})
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.debug("Unhandled channel info: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    session_id = socket.assigns[:session_id]
    Logger.info("User disconnected from proxy channel: #{session_id}, reason: #{inspect(reason)}")
    :ok
  end

  # Private functions

  defp authorized?(payload) do
    # Basic authorization - in production, implement proper authentication
    case Map.get(payload, "auth_token") do
      nil -> true  # Allow for development
      token -> validate_auth_token(token)
    end
  end

  defp validate_auth_token(_token) do
    # Implement token validation logic here
    # For now, always return true for development
    true
  end

  defp handle_query(pid, query, payload, socket) do
    opts = build_query_options(payload)

    case ConversationServer.process_query(pid, query, opts) do
      {:ok, response, metadata} ->
        push(socket, "response", %{
          response: response,
          metadata: metadata,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        # Emit usage metrics
        :telemetry.execute(
          [:neural_bridge, :channel, :query],
          %{processing_time: metadata[:processing_time_ms] || 0},
          %{source: metadata[:source], session_id: socket.assigns.session_id}
        )

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Query processing failed: #{inspect(reason)}")

        push(socket, "error", %{
          error: "processing_failed",
          message: "Failed to process query",
          reason: inspect(reason)
        })

        {:noreply, socket}
    end
  end

  defp handle_streaming_query(pid, query, payload, socket) do
    _opts = [streaming: true] ++ build_query_options(payload)

    # Start streaming response
    push(socket, "stream_start", %{
      query: query,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    # Process query with streaming callback
    ConversationServer.stream_response(pid, query, self())

    {:noreply, socket}
  end

  defp build_query_options(payload) do
    []
    |> maybe_add_option(:model, payload["model"])
    |> maybe_add_option(:temperature, payload["temperature"])
    |> maybe_add_option(:max_tokens, payload["max_tokens"])
    |> maybe_add_option(:metadata, payload["metadata"])
  end

  defp maybe_add_option(opts, _key, nil), do: opts
  defp maybe_add_option(opts, key, value), do: [{key, value} | opts]

  defp format_messages(messages) do
    Enum.map(messages, fn message ->
      %{
        id: message.id,
        role: message.role,
        content: message.content,
        metadata: message.metadata,
        timestamp: message.inserted_at |> DateTime.to_iso8601()
      }
    end)
  end
end