defmodule NeuralBridge.LLM do
  require Logger

  @max_retries 3

  # Configuration based on environment variables
  def config do
    %{
      provider: System.get_env("LLM_PROVIDER", "openai") |> String.to_atom(),
      openai: %{
        api_key: System.get_env("OPENAI_API_KEY"),
        base_url: System.get_env("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        default_model: System.get_env("OPENAI_DEFAULT_MODEL", "gpt-4"),
        default_temperature: System.get_env("OPENAI_DEFAULT_TEMPERATURE", "0.7") |> String.to_float(),
        max_tokens: System.get_env("OPENAI_MAX_TOKENS", "2048") |> String.to_integer()
      },
      ollama: %{
        base_url: System.get_env("OLLAMA_BASE_URL", "http://localhost:11434"),
        default_model: System.get_env("OLLAMA_DEFAULT_MODEL", "llama2")
      }
    }
  end

  def generate_response(query, context \\ "", rag_context \\ [], opts \\ []) do
    cfg = config()

    # Use default environment configuration if not specified
    provider = Keyword.get(opts, :provider, cfg.provider)
    model = Keyword.get(opts, :model, get_default_model(provider, cfg))
    streaming = Keyword.get(opts, :streaming, false)
    temperature = Keyword.get(opts, :temperature, get_default_temperature(provider, cfg))

    system_prompt = build_system_prompt(rag_context)
    messages = build_messages(system_prompt, context, query)

    case provider do
      :openai ->
        call_openai_chat(messages, model, temperature, streaming)

      :ollama ->
        call_ollama_chat(messages, model, temperature, streaming)

      _ ->
        {:error, :unsupported_provider}
    end
  end

  def generate_embedding(text, opts \\ []) do
    cfg = config()
    provider = Keyword.get(opts, :provider, cfg.provider)
    model = Keyword.get(opts, :model, get_default_embedding_model(provider))

    case provider do
      :openai ->
        call_openai_embedding(text, model)

      :ollama ->
        call_ollama_embedding(text, model)

      _ ->
        {:error, :unsupported_provider}
    end
  end

  # Helper functions for configuration
  defp get_default_model(:openai, cfg), do: cfg.openai.default_model
  defp get_default_model(:ollama, cfg), do: cfg.ollama.default_model
  defp get_default_model(_, _), do: "gpt-4"

  defp get_default_temperature(:openai, cfg), do: cfg.openai.default_temperature
  defp get_default_temperature(:ollama, _), do: 0.7
  defp get_default_temperature(_, _), do: 0.7

  defp get_default_embedding_model(:openai), do: "text-embedding-ada-002"
  defp get_default_embedding_model(:ollama), do: "llama2"
  defp get_default_embedding_model(_), do: "text-embedding-ada-002"

  def list_available_models(provider \\ :openai) do
    case provider do
      :openai ->
        get_openai_models()

      :ollama ->
        get_ollama_models()

      _ ->
        {:error, :unsupported_provider}
    end
  end

  def test_connection(provider \\ :openai) do
    case provider do
      :openai ->
        test_openai_connection()

      :ollama ->
        test_ollama_connection()

      _ ->
        {:error, :unsupported_provider}
    end
  end

  # Private functions

  defp build_system_prompt(rag_context) when is_list(rag_context) and length(rag_context) > 0 do
    context_text =
      rag_context
      |> Enum.map_join("\n\n", fn chunk ->
        "Source: #{chunk[:source_document] || "Unknown"}\n#{chunk[:content]}"
      end)

    """
    You are a helpful AI assistant. Use the following context information to answer questions accurately.
    If the context doesn't contain relevant information, say so clearly.

    Context:
    #{context_text}

    Instructions:
    - Answer based on the provided context when relevant
    - Be specific and cite sources when possible
    - If information is not in the context, clearly state that
    - Maintain a helpful and informative tone
    """
  end

  defp build_system_prompt(_), do: "You are a helpful AI assistant."

  defp build_messages(system_prompt, context, query) do
    messages = [
      %{role: "system", content: system_prompt}
    ]

    messages =
      if context != "" do
        # Parse context into conversation history
        context_messages = parse_context_to_messages(context)
        messages ++ context_messages
      else
        messages
      end

    messages ++ [%{role: "user", content: query}]
  end

  defp parse_context_to_messages(context) do
    # Simple parsing of "role: content" format
    context
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      case String.split(line, ": ", parts: 2) do
        [role, content] when role in ["user", "assistant", "system"] ->
          %{role: role, content: content}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(-10)  # Keep last 10 messages for context
  end

  defp call_openai_chat(messages, model, temperature, streaming) do
    cfg = config()
    api_key = cfg.openai.api_key

    if is_nil(api_key) do
      {:error, :missing_api_key}
    else
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      body = %{
        model: model,
        messages: messages,
        temperature: temperature,
        stream: streaming,
        max_tokens: cfg.openai.max_tokens
      }

      case Req.post("#{cfg.openai.base_url}/chat/completions",
             json: body,
             headers: headers,
             receive_timeout: 60_000
           ) do
        {:ok, %{status: 200, body: response}} ->
          parse_openai_chat_response(response, streaming)

        {:ok, %{status: status, body: body}} ->
          Logger.error("OpenAI API error: #{status} - #{inspect(body)}")
          {:error, :api_error}

        {:error, reason} ->
          Logger.error("OpenAI request failed: #{inspect(reason)}")
          {:error, :request_failed}
      end
    end
  end

  defp call_ollama_chat(messages, model, temperature, streaming) do
    cfg = config()

    body = %{
      model: model,
      messages: messages,
      stream: streaming,
      options: %{
        temperature: temperature
      }
    }

    case Req.post("#{cfg.ollama.base_url}/api/chat",
           json: body,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: response}} ->
        parse_ollama_chat_response(response, streaming)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Ollama API error: #{status} - #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Ollama request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  defp call_openai_embedding(text, model) do
    api_key = get_openai_api_key()

    if is_nil(api_key) do
      {:error, :missing_api_key}
    else
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      body = %{
        model: model,
        input: text
      }

      case Req.post("#{@openai_api_url}/embeddings",
             json: body,
             headers: headers,
             receive_timeout: 30_000
           ) do
        {:ok, %{status: 200, body: %{"data" => [%{"embedding" => embedding}]}}} ->
          {:ok, embedding}

        {:ok, %{status: status, body: body}} ->
          Logger.error("OpenAI Embedding API error: #{status} - #{inspect(body)}")
          {:error, :api_error}

        {:error, reason} ->
          Logger.error("OpenAI embedding request failed: #{inspect(reason)}")
          {:error, :request_failed}
      end
    end
  end

  defp call_ollama_embedding(text, model) do
    body = %{
      model: model,
      prompt: text
    }

    case Req.post("#{@ollama_api_url}/embeddings",
           json: body,
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: %{"embedding" => embedding}}} ->
        {:ok, embedding}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Ollama Embedding API error: #{status} - #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Ollama embedding request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  defp parse_openai_chat_response(%{"choices" => [%{"message" => %{"content" => content}}]}, false) do
    # Estimate confidence based on response characteristics
    confidence_score = estimate_confidence(content)
    {:ok, content, confidence_score}
  end

  defp parse_openai_chat_response(response, true) do
    # Handle streaming response
    # This is a simplified version - full streaming would require handling SSE
    case response do
      %{"choices" => [%{"delta" => %{"content" => content}}]} ->
        confidence_score = estimate_confidence(content)
        {:ok, content, confidence_score}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp parse_openai_chat_response(_, _), do: {:error, :invalid_response}

  defp parse_ollama_chat_response(%{"message" => %{"content" => content}}, false) do
    confidence_score = estimate_confidence(content)
    {:ok, content, confidence_score}
  end

  defp parse_ollama_chat_response(response, true) do
    # Handle Ollama streaming response
    case response do
      %{"message" => %{"content" => content}} ->
        confidence_score = estimate_confidence(content)
        {:ok, content, confidence_score}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp parse_ollama_chat_response(_, _), do: {:error, :invalid_response}

  defp estimate_confidence(content) do
    # Simple heuristic-based confidence estimation
    # In production, this could be more sophisticated
    cond do
      String.length(content) < 10 -> 0.3
      String.contains?(content, ["I don't know", "I'm not sure", "unclear"]) -> 0.4
      String.contains?(content, ["possibly", "might", "perhaps"]) -> 0.6
      String.length(content) > 100 -> 0.8
      true -> 0.7
    end
  end

  defp get_openai_models do
    api_key = get_openai_api_key()

    if is_nil(api_key) do
      {:error, :missing_api_key}
    else
      headers = [
        {"Authorization", "Bearer #{api_key}"}
      ]

      case Req.get("#{@openai_api_url}/models", headers: headers) do
        {:ok, %{status: 200, body: %{"data" => models}}} ->
          model_names = Enum.map(models, & &1["id"])
          {:ok, model_names}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp get_ollama_models do
    case Req.get("#{@ollama_api_url}/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        model_names = Enum.map(models, & &1["name"])
        {:ok, model_names}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp test_openai_connection do
    case get_openai_models() do
      {:ok, _models} -> {:ok, :connected}
      error -> error
    end
  end

  defp test_ollama_connection do
    case Req.get("#{@ollama_api_url}/tags") do
      {:ok, %{status: 200}} -> {:ok, :connected}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_openai_api_key do
    Application.get_env(:neural_bridge, :openai_api_key) ||
      System.get_env("OPENAI_API_KEY")
  end
end