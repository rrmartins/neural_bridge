defmodule NeuralBridge.ConversationServer do
  use GenServer, restart: :temporary
  require Logger

  alias NeuralBridge.{Repo, Cache, RAG, LLM, Guardrails}
  alias NeuralBridge.Schemas.{Conversation, Message, QueryLog}
  alias NeuralBridge.Tools.APIB

  @session_timeout :timer.minutes(30)
  @max_context_messages 50

  defstruct [
    :conversation_id,
    :session_id,
    :user_id,
    :last_activity,
    messages: [],
    metadata: %{}
  ]

  # Client API

  def start_link(%{session_id: session_id} = opts) do
    name = {:via, Registry, {NeuralBridge.ConversationRegistry, session_id}}
    GenServer.start_link(__MODULE__, opts, name: name, timeout: 30_000)
  end

  def get_or_start_conversation(session_id, user_id \\ nil) do
    case Registry.lookup(NeuralBridge.ConversationRegistry, session_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        conversation_opts = %{
          session_id: session_id,
          user_id: user_id,
          conversation_id: UUID.uuid4()
        }

        case DynamicSupervisor.start_child(
               NeuralBridge.ConversationSupervisor,
               {__MODULE__, conversation_opts}
             ) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end
    end
  end

  def process_query(pid, query, opts \\ []) do
    GenServer.call(pid, {:process_query, query, opts}, 30_000)
  end

  def get_conversation_history(pid) do
    GenServer.call(pid, :get_history)
  end

  def stream_response(pid, query, callback_pid) do
    GenServer.cast(pid, {:stream_response, query, callback_pid})
  end

  # Server callbacks

  @impl true
  def init(%{session_id: session_id, conversation_id: conversation_id, user_id: user_id}) do
    Process.flag(:trap_exit, true)

    state = %__MODULE__{
      conversation_id: conversation_id,
      session_id: session_id,
      user_id: user_id,
      last_activity: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    # Load or create conversation record
    conversation = get_or_create_conversation(conversation_id, session_id, user_id)

    # Load recent messages for context
    messages = load_recent_messages(conversation_id)

    updated_state = %{state | messages: messages}

    # Set session timeout
    :timer.send_after(@session_timeout, :timeout)

    Logger.info("Started conversation server for session: #{session_id}")

    {:ok, updated_state}
  end

  @impl true
  def handle_call({:process_query, query, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # Update last activity
      state = %{state | last_activity: DateTime.utc_now() |> DateTime.truncate(:second)}

      # Process the query through the pipeline
      result = process_query_pipeline(query, state, opts)

      # Add user message to context
      user_message = create_message(state.conversation_id, "user", query, %{})
      save_message(user_message)

      case result do
        {:ok, response, metadata} ->
          # Add assistant message to context
          assistant_message =
            create_message(state.conversation_id, "assistant", response, metadata)

          save_message(assistant_message)

          # Update state with new messages
          new_messages = [user_message, assistant_message | state.messages]
          updated_state = %{state | messages: Enum.take(new_messages, @max_context_messages)}

          # Log the query for training
          log_query(state.conversation_id, query, response, metadata)

          # Emit metrics
          processing_time = System.monotonic_time(:millisecond) - start_time
          :telemetry.execute(
            [:neural_bridge, :query, :processed],
            %{processing_time: processing_time},
            %{source: metadata[:source], status: "success"}
          )

          {:reply, {:ok, response, metadata}, updated_state}

        {:error, reason} ->
          # Emit error metrics
          processing_time = System.monotonic_time(:millisecond) - start_time
          :telemetry.execute(
            [:neural_bridge, :query, :processed],
            %{processing_time: processing_time},
            %{source: "error", status: "error"}
          )

          {:reply, {:error, reason}, state}
      end
    rescue
      error ->
        Logger.error("Error processing query: #{inspect(error)}")
        {:reply, {:error, "Internal server error"}, state}
    end
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, {:ok, Enum.reverse(state.messages)}, state}
  end

  @impl true
  def handle_cast({:stream_response, query, callback_pid}, state) do
    # Spawn a task to handle streaming response
    Task.start(fn ->
      case process_query_pipeline(query, state, streaming: true) do
        {:ok, response, metadata} ->
          # Stream tokens back to callback_pid
          stream_tokens(callback_pid, response)

        {:error, reason} ->
          send(callback_pid, {:error, reason})
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Conversation #{state.session_id} timed out, shutting down")
    {:stop, :normal, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Conversation server #{state.session_id} terminating: #{inspect(reason)}")
    :ok
  end

  # Private functions

  defp process_query_pipeline(query, state, opts \\ []) do
    context = build_context(state.messages)

    # Step 1: Check cache
    case Cache.get(query, context) do
      {:ok, cached_response} ->
        :telemetry.execute([:neural_bridge, :cache, :accessed], %{}, %{result: "hit"})
        {:ok, cached_response, %{source: "cache", confidence_score: 1.0}}

      {:error, :not_found} ->
        :telemetry.execute([:neural_bridge, :cache, :accessed], %{}, %{result: "miss"})

        # Step 2: Try RAG + LLM
        case process_with_rag_and_llm(query, context, opts) do
          {:ok, response, metadata} ->
            # Cache the response
            Cache.put(query, context, response)
            {:ok, response, metadata}

          {:error, :low_confidence} ->
            # Step 3: Fallback to API B
            process_with_api_b(query, context, opts)

          error ->
            error
        end
    end
  end

  defp process_with_rag_and_llm(query, context, opts) do
    # Retrieve relevant context from RAG
    case RAG.retrieve(query, limit: 5) do
      {:ok, rag_context} ->
        # Generate response with LLM
        start_time = System.monotonic_time(:millisecond)

        case LLM.generate_response(query, context, rag_context, opts) do
          {:ok, response, confidence_score} ->
            processing_time = System.monotonic_time(:millisecond) - start_time

            :telemetry.execute(
              [:neural_bridge, :llm, :response],
              %{processing_time: processing_time},
              %{}
            )

            :telemetry.execute(
              [:neural_bridge, :llm, :confidence],
              %{confidence_score: confidence_score * 100},
              %{}
            )

            # Validate response with guardrails
            case Guardrails.validate_response(response, query) do
              {:ok, validated_response} ->
                if confidence_score >= 0.7 do
                  {:ok, validated_response,
                   %{
                     source: "llm",
                     confidence_score: confidence_score,
                     processing_time_ms: processing_time,
                     rag_context_used: length(rag_context)
                   }}
                else
                  {:error, :low_confidence}
                end

              {:error, _reason} ->
                {:error, :validation_failed}
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  defp process_with_api_b(query, context, opts) do
    start_time = System.monotonic_time(:millisecond)

    case APIB.call(query, context, opts) do
      {:ok, response} ->
        processing_time = System.monotonic_time(:millisecond) - start_time

        :telemetry.execute(
          [:neural_bridge, :api_b, :fallback],
          %{},
          %{reason: "low_confidence"}
        )

        :telemetry.execute(
          [:neural_bridge, :api_b, :response],
          %{processing_time: processing_time},
          %{}
        )

        {:ok, response,
         %{
           source: "api_b",
           confidence_score: 1.0,
           processing_time_ms: processing_time
         }}

      error ->
        :telemetry.execute(
          [:neural_bridge, :api_b, :fallback],
          %{},
          %{reason: "error"}
        )

        error
    end
  end

  defp build_context(messages) do
    messages
    |> Enum.take(10)
    |> Enum.map(fn msg -> "#{msg.role}: #{msg.content}" end)
    |> Enum.join("\n")
  end

  defp stream_tokens(callback_pid, response) do
    # Simulate token streaming by splitting response into chunks
    response
    |> String.split(" ")
    |> Enum.each(fn token ->
      send(callback_pid, {:token, token <> " "})
      Process.sleep(50)
    end)

    send(callback_pid, {:done})
  end

  defp get_or_create_conversation(conversation_id, session_id, user_id) do
    case Repo.get(Conversation, conversation_id) do
      nil ->
        %Conversation{
          id: conversation_id,
          session_id: session_id,
          user_id: user_id,
          last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        |> Repo.insert!()

      conversation ->
        conversation
        |> Ecto.Changeset.change(last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()
    end
  end

  defp load_recent_messages(conversation_id) do
    import Ecto.Query

    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [desc: m.inserted_at],
      limit: @max_context_messages
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  defp create_message(conversation_id, role, content, metadata) do
    %Message{
      id: UUID.uuid4(),
      conversation_id: conversation_id,
      role: role,
      content: content,
      metadata: metadata
    }
  end

  defp save_message(message) do
    Repo.insert(message)
  end

  defp log_query(conversation_id, query, response, metadata) do
    %QueryLog{
      id: UUID.uuid4(),
      conversation_id: conversation_id,
      query: query,
      response: response,
      source: metadata[:source],
      confidence_score: metadata[:confidence_score],
      processing_time_ms: metadata[:processing_time_ms],
      api_b_called: metadata[:source] == "api_b",
      metadata: metadata
    }
    |> Repo.insert()
  end
end