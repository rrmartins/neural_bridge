defmodule NeuralBridge.Tools.APIB do
  require Logger

  @moduledoc """
  Module for calling external API B as a fallback when local LLM confidence is low.
  This is a placeholder implementation that can be customized for your specific API B.
  """

  @default_timeout 30_000
  @max_retries 3

  def call(query, context \\ "", opts \\ []) do
    endpoint = get_api_endpoint()
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retries, @max_retries)

    if is_nil(endpoint) do
      Logger.warning("API B endpoint not configured, using mock response")
      mock_api_b_response(query, context)
    else
      call_with_retries(endpoint, query, context, opts, retries, timeout)
    end
  end

  def health_check do
    endpoint = get_api_endpoint()

    if is_nil(endpoint) do
      {:ok, :mock_mode}
    else
      case Req.get("#{endpoint}/health", receive_timeout: 5_000) do
        {:ok, %{status: 200}} ->
          {:ok, :healthy}

        {:ok, %{status: status}} ->
          {:error, {:unhealthy, status}}

        {:error, reason} ->
          {:error, {:connection_failed, reason}}
      end
    end
  end

  def get_api_info do
    endpoint = get_api_endpoint()

    if is_nil(endpoint) do
      {:ok, %{
        status: "mock",
        endpoint: "none",
        description: "Mock API B for testing"
      }}
    else
      case Req.get("#{endpoint}/info", receive_timeout: 5_000) do
        {:ok, %{status: 200, body: info}} ->
          {:ok, info}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Private functions

  defp call_with_retries(endpoint, query, context, opts, retries, timeout) when retries > 0 do
    case make_api_call(endpoint, query, context, opts, timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, :rate_limited} ->
        # Exponential backoff for rate limits
        backoff_time = ((@max_retries - retries + 1) * 1000)
        Logger.info("Rate limited, backing off for #{backoff_time}ms")
        Process.sleep(backoff_time)
        call_with_retries(endpoint, query, context, opts, retries - 1, timeout)

      {:error, :timeout} when retries > 1 ->
        Logger.warning("API B timeout, retrying (#{retries - 1} retries left)")
        call_with_retries(endpoint, query, context, opts, retries - 1, timeout)

      {:error, reason} when retries > 1 ->
        Logger.warning("API B error: #{inspect(reason)}, retrying (#{retries - 1} retries left)")
        call_with_retries(endpoint, query, context, opts, retries - 1, timeout)

      error ->
        error
    end
  end

  defp call_with_retries(_endpoint, _query, _context, _opts, 0, _timeout) do
    {:error, :max_retries_exceeded}
  end

  defp make_api_call(endpoint, query, context, opts, timeout) do
    headers = build_headers()
    body = build_request_body(query, context, opts)

    case Req.post("#{endpoint}/query",
           json: body,
           headers: headers,
           receive_timeout: timeout
         ) do
      {:ok, %{status: 200, body: response}} ->
        parse_api_response(response)

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: 408}} ->
        {:error, :timeout}

      {:ok, %{status: status, body: body}} ->
        Logger.error("API B error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("API B request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp build_headers do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "NeuralBridge/1.0"}
    ]

    # Add authentication if API key is available
    case get_api_key() do
      nil ->
        headers

      api_key ->
        [{"Authorization", "Bearer #{api_key}"} | headers]
    end
  end

  defp build_request_body(query, context, opts) do
    base_body = %{
      query: query,
      context: context,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Add optional parameters
    opts
    |> Enum.reduce(base_body, fn
      {:max_tokens, tokens}, acc -> Map.put(acc, :max_tokens, tokens)
      {:temperature, temp}, acc -> Map.put(acc, :temperature, temp)
      {:model, model}, acc -> Map.put(acc, :model, model)
      {:metadata, metadata}, acc -> Map.put(acc, :metadata, metadata)
      {_key, _value}, acc -> acc
    end)
  end

  defp parse_api_response(%{"response" => response} = body) when is_binary(response) do
    metadata = Map.get(body, "metadata", %{})
    {:ok, %{response: response, metadata: metadata}}
  end

  defp parse_api_response(%{"error" => error}) do
    {:error, {:api_error, error}}
  end

  defp parse_api_response(response) do
    Logger.warning("Unexpected API B response format: #{inspect(response)}")
    {:error, :invalid_response_format}
  end

  # Mock response for testing when API B is not configured
  defp mock_api_b_response(query, _context) do
    # Simulate API processing time
    Process.sleep(Enum.random(500..2000))

    responses = [
      "Based on my knowledge, #{query} is an interesting topic that requires careful consideration of various factors.",
      "I understand you're asking about #{query}. This is a complex subject with multiple perspectives to consider.",
      "Regarding #{query}, there are several important aspects to keep in mind when approaching this topic.",
      "The question about #{query} touches on important concepts that are worth exploring in detail.",
      "When considering #{query}, it's helpful to examine both the theoretical and practical implications."
    ]

    response = Enum.random(responses)

    {:ok, %{
      response: response,
      metadata: %{
        source: "mock_api_b",
        processing_time_ms: Enum.random(500..2000),
        model: "mock-model-v1",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }}
  end

  defp get_api_endpoint do
    Application.get_env(:neural_bridge, :api_b_endpoint) ||
      System.get_env("API_B_ENDPOINT")
  end

  defp get_api_key do
    Application.get_env(:neural_bridge, :api_b_key) ||
      System.get_env("API_B_KEY")
  end
end