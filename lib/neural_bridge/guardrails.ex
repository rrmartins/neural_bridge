defmodule NeuralBridge.Guardrails do
  require Logger

  @moduledoc """
  Guardrails module for validating and filtering LLM responses.
  Ensures responses meet quality, safety, and format requirements.
  """

  # Content filters
  @toxic_patterns [
    ~r/\b(hate|violence|harm|toxic|offensive)\b/i,
    ~r/\b(kill|murder|suicide|death)\b/i,
    ~r/\b(racist|sexist|discriminatory)\b/i
  ]

  @personal_info_patterns [
    ~r/\b\d{3}-\d{2}-\d{4}\b/,  # SSN
    ~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/,  # Credit card
    ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/  # Email
  ]

  @quality_thresholds %{
    min_length: 10,
    max_length: 10_000,
    min_word_count: 3,
    max_repetition_ratio: 0.3
  }

  def validate_response(response, query \\ "", opts \\ []) do
    with :ok <- validate_content_safety(response, opts),
         :ok <- validate_privacy(response, opts),
         :ok <- validate_quality(response, opts),
         :ok <- validate_relevance(response, query, opts),
         {:ok, filtered_response} <- apply_content_filters(response, opts) do
      {:ok, filtered_response}
    else
      {:error, reason} -> {:error, reason}
      error -> error
    end
  end

  def validate_query(query, opts \\ []) do
    with :ok <- validate_query_safety(query, opts),
         :ok <- validate_query_length(query, opts) do
      :ok
    else
      error -> error
    end
  end

  def validate_json_schema(data, schema_name) when is_map(data) do
    case get_schema(schema_name) do
      {:ok, schema} ->
        case ExJsonSchema.Validator.validate(schema, data) do
          :ok -> {:ok, data}
          {:error, errors} -> {:error, {:schema_validation_failed, errors}}
        end

      {:error, reason} ->
        {:error, {:schema_not_found, reason}}
    end
  end

  def validate_json_schema(_data, _schema_name) do
    {:error, :invalid_data_format}
  end

  def sanitize_output(content, opts \\ []) do
    content
    |> remove_sensitive_info(opts)
    |> clean_markdown(opts)
    |> limit_length(opts)
    |> trim_whitespace()
  end

  def check_content_toxicity(content) do
    toxic_score = calculate_toxicity_score(content)

    cond do
      toxic_score > 0.8 -> {:error, :high_toxicity}
      toxic_score > 0.6 -> {:warning, :moderate_toxicity}
      true -> :ok
    end
  end

  def validate_code_output(code, language \\ nil) do
    with :ok <- check_code_safety(code),
         :ok <- validate_code_syntax(code, language) do
      {:ok, code}
    else
      error -> error
    end
  end

  # Private functions

  defp validate_content_safety(content, opts) do
    strict_mode = Keyword.get(opts, :strict_safety, true)

    case check_content_toxicity(content) do
      :ok ->
        :ok

      {:warning, :moderate_toxicity} when not strict_mode ->
        Logger.warning("Moderate toxicity detected in response")
        :ok

      {:warning, :moderate_toxicity} ->
        {:error, :content_safety_violation}

      {:error, :high_toxicity} ->
        {:error, :content_safety_violation}
    end
  end

  defp validate_privacy(content, _opts) do
    if contains_personal_info?(content) do
      {:error, :privacy_violation}
    else
      :ok
    end
  end

  defp validate_quality(content, opts) do
    thresholds = Map.merge(@quality_thresholds, Keyword.get(opts, :quality_thresholds, %{}))

    cond do
      String.length(content) < thresholds.min_length ->
        {:error, :response_too_short}

      String.length(content) > thresholds.max_length ->
        {:error, :response_too_long}

      word_count(content) < thresholds.min_word_count ->
        {:error, :insufficient_content}

      repetition_ratio(content) > thresholds.max_repetition_ratio ->
        {:error, :excessive_repetition}

      true ->
        :ok
    end
  end

  defp validate_relevance(response, query, opts) do
    if query == "" do
      :ok
    else
      min_relevance = Keyword.get(opts, :min_relevance_score, 0.3)
      relevance_score = calculate_relevance_score(response, query)

      if relevance_score >= min_relevance do
        :ok
      else
        {:error, :low_relevance}
      end
    end
  end

  defp apply_content_filters(content, opts) do
    filtered_content =
      content
      |> filter_sensitive_patterns(opts)
      |> sanitize_output(opts)

    {:ok, filtered_content}
  end

  defp validate_query_safety(query, _opts) do
    case check_content_toxicity(query) do
      :ok -> :ok
      {:warning, _} -> :ok  # Allow warnings for queries
      {:error, _} -> {:error, :unsafe_query}
    end
  end

  defp validate_query_length(query, opts) do
    max_length = Keyword.get(opts, :max_query_length, 5000)

    if String.length(query) > max_length do
      {:error, :query_too_long}
    else
      :ok
    end
  end

  defp calculate_toxicity_score(content) do
    # Simple pattern-based toxicity detection
    # In production, this could use a ML model
    content_lower = String.downcase(content)

    toxic_patterns = [
      ~r/\b(hate|violence|harm|toxic|offensive)\b/i,
      ~r/\b(kill|murder|suicide|death)\b/i,
      ~r/\b(racist|sexist|discriminatory)\b/i
    ]

    toxic_matches =
      toxic_patterns
      |> Enum.map(fn pattern -> Regex.scan(pattern, content_lower) |> length() end)
      |> Enum.sum()

    # Normalize by content length
    max_score = min(toxic_matches / (String.length(content) / 100), 1.0)
    max_score
  end

  defp contains_personal_info?(content) do
    personal_info_patterns = [
      ~r/\b\d{3}-\d{2}-\d{4}\b/,  # SSN
      ~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/,  # Credit card
      ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/  # Email
    ]

    personal_info_patterns
    |> Enum.any?(fn pattern -> Regex.match?(pattern, content) end)
  end

  defp word_count(content) do
    content
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp repetition_ratio(content) do
    words = String.split(content, ~r/\s+/, trim: true)
    unique_words = Enum.uniq(words)

    if length(words) == 0 do
      0
    else
      1 - (length(unique_words) / length(words))
    end
  end

  defp calculate_relevance_score(response, query) do
    # Simple keyword overlap-based relevance
    query_words = extract_keywords(query)
    response_words = extract_keywords(response)

    if length(query_words) == 0 do
      0.5  # Neutral score for empty query
    else
      overlap = MapSet.intersection(MapSet.new(query_words), MapSet.new(response_words))
      MapSet.size(overlap) / length(query_words)
    end
  end

  defp extract_keywords(text) do
    # Simple keyword extraction
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(String.length(&1) < 3))  # Filter out short words
    |> Enum.reject(&(&1 in ["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use"]))
  end

  defp filter_sensitive_patterns(content, _opts) do
    # Remove or mask sensitive patterns
    personal_info_patterns = [
      ~r/\b\d{3}-\d{2}-\d{4}\b/,  # SSN
      ~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/,  # Credit card
      ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/  # Email
    ]

    personal_info_patterns
    |> Enum.reduce(content, fn pattern, acc ->
      Regex.replace(pattern, acc, "[REDACTED]")
    end)
  end

  defp remove_sensitive_info(content, _opts) do
    # Additional sensitive info removal
    content
    |> String.replace(~r/password:\s*\S+/i, "password: [REDACTED]")
    |> String.replace(~r/token:\s*\S+/i, "token: [REDACTED]")
    |> String.replace(~r/key:\s*\S+/i, "key: [REDACTED]")
  end

  defp clean_markdown(content, opts) do
    if Keyword.get(opts, :clean_markdown, false) do
      content
      |> String.replace(~r/```[^`]*```/m, "[CODE BLOCK]")
      |> String.replace(~r/`[^`]+`/, "[CODE]")
    else
      content
    end
  end

  defp limit_length(content, opts) do
    max_length = Keyword.get(opts, :max_output_length, @quality_thresholds.max_length)

    if String.length(content) > max_length do
      String.slice(content, 0, max_length - 3) <> "..."
    else
      content
    end
  end

  defp trim_whitespace(content) do
    String.trim(content)
  end

  defp check_code_safety(code) do
    # Check for potentially dangerous code patterns
    dangerous_patterns = [
      ~r/\beval\b/i,
      ~r/\bexec\b/i,
      ~r/\bsystem\b/i,
      ~r/\bos\.system\b/i,
      ~r/\bsubprocess\b/i,
      ~r/\b__import__\b/i,
      ~r/\brm\s+-rf\b/i,
      ~r/\bdel\b.*\*\*/i
    ]

    if Enum.any?(dangerous_patterns, &Regex.match?(&1, code)) do
      {:error, :potentially_dangerous_code}
    else
      :ok
    end
  end

  defp validate_code_syntax(_code, nil), do: :ok

  defp validate_code_syntax(code, language) do
    # Basic syntax validation for common languages
    # In production, this could use language-specific parsers
    case language do
      "json" -> validate_json_syntax(code)
      "yaml" -> validate_yaml_syntax(code)
      _ -> :ok  # Skip validation for unknown languages
    end
  end

  defp validate_json_syntax(json_string) do
    case Jason.decode(json_string) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :invalid_json_syntax}
    end
  end

  defp validate_yaml_syntax(_yaml_string) do
    # Would need a YAML parser for this
    :ok
  end

  defp get_schema(schema_name) do
    # Define common schemas
    schemas = %{
      "api_response" => %{
        "type" => "object",
        "properties" => %{
          "data" => %{"type" => "object"},
          "status" => %{"type" => "string"},
          "message" => %{"type" => "string"}
        },
        "required" => ["status"]
      },
      "query_request" => %{
        "type" => "object",
        "properties" => %{
          "query" => %{"type" => "string"},
          "context" => %{"type" => "string"},
          "options" => %{"type" => "object"}
        },
        "required" => ["query"]
      }
    }

    case Map.get(schemas, schema_name) do
      nil -> {:error, :schema_not_found}
      schema -> {:ok, ExJsonSchema.Schema.resolve(schema)}
    end
  end
end