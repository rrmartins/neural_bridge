defmodule NeuralBridgeWeb.ProxyController do
  use NeuralBridgeWeb, :controller

  alias NeuralBridge.ConversationServer
  alias NeuralBridge.{Cache, LLM}
  alias NeuralBridge.Tools.APIB
  require Logger

  def query(conn, params) do
    with {:ok, validated_params} <- validate_query_params(params),
         {:ok, pid} <- get_or_start_conversation(validated_params),
         {:ok, response, metadata} <- process_query(pid, validated_params) do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        response: response,
        metadata: metadata,
        session_id: validated_params["session_id"]
      })
    else
      {:error, :invalid_params} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid parameters",
          message: "Required: query, session_id"
        })

      {:error, reason} ->
        Logger.error("Query processing failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Processing failed",
          message: "Unable to process query at this time"
        })
    end
  end

  def health(conn, _params) do
    health_checks = [
      {"cache", check_cache_health()},
      {"database", check_database_health()},
      {"llm_openai", check_llm_health(:openai)},
      {"llm_ollama", check_llm_health(:ollama)},
      {"api_b", check_api_b_health()}
    ]

    all_healthy = Enum.all?(health_checks, fn {_name, status} -> status == :ok end)

    status_code = if all_healthy, do: :ok, else: :service_unavailable

    conn
    |> put_status(status_code)
    |> json(%{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: Map.new(health_checks)
    })
  end

  def stats(conn, _params) do
    stats = %{
      cache: get_cache_stats(),
      conversations: get_conversation_stats(),
      system: get_system_stats(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    conn
    |> put_status(:ok)
    |> json(stats)
  end

  # Private functions

  defp validate_query_params(params) do
    required_fields = ["query", "session_id"]
    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(params, &1)))

    if Enum.empty?(missing_fields) do
      {:ok, params}
    else
      {:error, :invalid_params}
    end
  end

  defp get_or_start_conversation(params) do
    session_id = params["session_id"]
    user_id = params["user_id"]

    ConversationServer.get_or_start_conversation(session_id, user_id)
  end

  defp process_query(pid, params) do
    query = params["query"]
    opts = build_query_options(params)

    ConversationServer.process_query(pid, query, opts)
  end

  defp build_query_options(params) do
    []
    |> maybe_add_option(:streaming, params["streaming"])
    |> maybe_add_option(:model, params["model"])
    |> maybe_add_option(:temperature, params["temperature"])
    |> maybe_add_option(:max_tokens, params["max_tokens"])
  end

  defp maybe_add_option(opts, _key, nil), do: opts
  defp maybe_add_option(opts, key, value), do: [{key, value} | opts]

  defp check_cache_health do
    case Cache.size() do
      size when is_integer(size) -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp check_database_health do
    case NeuralBridge.Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp check_llm_health(provider) do
    case LLM.test_connection(provider) do
      {:ok, :connected} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp check_api_b_health do
    case APIB.health_check() do
      {:ok, _} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp get_cache_stats do
    %{
      size: Cache.size(),
      detailed_stats: Cache.stats()
    }
  rescue
    _ -> %{size: 0, detailed_stats: %{}}
  end

  defp get_conversation_stats do
    active_conversations = Registry.count(NeuralBridge.ConversationRegistry)

    %{
      active_conversations: active_conversations
    }
  rescue
    _ -> %{active_conversations: 0}
  end

  defp get_system_stats do
    memory_info = :erlang.memory() |> Enum.into(%{})

    %{
      memory_usage: memory_info,
      process_count: :erlang.system_info(:process_count),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    }
  rescue
    _ -> %{}
  end
end