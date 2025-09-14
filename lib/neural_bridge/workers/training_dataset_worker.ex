defmodule NeuralBridge.Workers.TrainingDatasetWorker do
  use Oban.Worker, queue: :default

  alias NeuralBridge.Repo
  alias NeuralBridge.Schemas.{QueryLog, TrainingJob}
  alias NeuralBridge.Workers.TrainJob
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting daily training dataset generation")

    with {:ok, stats} <- analyze_training_data(),
         {:ok, _job} <- maybe_trigger_training(stats) do
      Logger.info("Training dataset analysis completed successfully")
      :ok
    else
      {:error, reason} ->
        Logger.error("Training dataset generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp analyze_training_data do
    import Ecto.Query

    # Analyze query logs from the last 24 hours
    yesterday = DateTime.utc_now() |> DateTime.add(-24, :hour)

    stats =
      from(q in QueryLog,
        where: q.inserted_at >= ^yesterday,
        select: %{
          total_queries: count(),
          avg_confidence: avg(q.confidence_score),
          api_b_fallbacks: count(q.id) |> filter(q.api_b_called == true),
          high_confidence_responses: count(q.id) |> filter(q.confidence_score >= 0.8),
          user_feedback_available: count(q.id) |> filter(not is_nil(q.feedback_score)),
          positive_feedback: count(q.id) |> filter(q.feedback_score >= 4)
        }
      )
      |> Repo.one()

    # Calculate training readiness metrics
    fallback_rate = if stats.total_queries > 0, do: stats.api_b_fallbacks / stats.total_queries, else: 0
    feedback_rate = if stats.total_queries > 0, do: stats.user_feedback_available / stats.total_queries, else: 0

    enhanced_stats = Map.merge(stats, %{
      fallback_rate: fallback_rate,
      feedback_rate: feedback_rate,
      analysis_date: DateTime.utc_now()
    })

    Logger.info("Training data analysis: #{inspect(enhanced_stats)}")

    # Emit training data metrics
    :telemetry.execute(
      [:neural_bridge, :training, :data_analysis],
      %{
        total_queries: stats.total_queries,
        fallback_rate: fallback_rate * 100,
        avg_confidence: (stats.avg_confidence || 0) * 100,
        feedback_rate: feedback_rate * 100
      },
      %{}
    )

    {:ok, enhanced_stats}
  end

  defp maybe_trigger_training(stats) do
    cond do
      should_trigger_fine_tuning?(stats) ->
        Logger.info("Triggering fine-tuning job based on training data analysis")
        trigger_fine_tuning(stats)

      should_trigger_distillation?(stats) ->
        Logger.info("Triggering distillation job based on API B usage")
        trigger_distillation(stats)

      true ->
        Logger.info("No training needed based on current metrics")
        {:ok, :no_training_needed}
    end
  end

  defp should_trigger_fine_tuning?(stats) do
    # Trigger fine-tuning if:
    # 1. We have enough positive feedback
    # 2. Confidence scores are reasonable
    # 3. Not too many API B fallbacks
    stats.positive_feedback >= 50 and
      stats.avg_confidence >= 0.6 and
      stats.fallback_rate < 0.3
  end

  defp should_trigger_distillation?(stats) do
    # Trigger distillation if:
    # 1. High API B usage (lots of fallbacks)
    # 2. Reasonable amount of API B responses to learn from
    stats.fallback_rate > 0.4 and
      stats.api_b_fallbacks >= 100
  end

  defp trigger_fine_tuning(stats) do
    config = %{
      "trigger_reason" => "daily_analysis",
      "dataset_limit" => min(1000, stats.positive_feedback * 2),
      "learning_rate" => calculate_learning_rate(stats),
      "epochs" => 3,
      "validation_split" => 0.2,
      "analysis_stats" => stats
    }

    TrainJob.enqueue_fine_tune_job(config)
  end

  defp trigger_distillation(stats) do
    config = %{
      "trigger_reason" => "high_api_b_usage",
      "sample_limit" => min(500, stats.api_b_fallbacks),
      "teacher_confidence_threshold" => 0.8,
      "analysis_stats" => stats
    }

    TrainJob.enqueue_distillation_job(config)
  end

  defp calculate_learning_rate(stats) do
    # Adjust learning rate based on confidence scores
    # Lower confidence = higher learning rate (more aggressive training)
    base_rate = 0.0001

    case stats.avg_confidence do
      conf when conf >= 0.8 -> base_rate * 0.5  # Conservative
      conf when conf >= 0.6 -> base_rate         # Normal
      _ -> base_rate * 2.0                       # Aggressive
    end
  end
end