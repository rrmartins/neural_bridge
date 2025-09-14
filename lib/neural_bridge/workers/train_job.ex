defmodule NeuralBridge.Workers.TrainJob do
  use Oban.Worker, queue: :training, max_attempts: 1

  alias NeuralBridge.{Repo, LLM}
  alias NeuralBridge.Schemas.{TrainingJob, QueryLog}
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"training_job_id" => training_job_id}}) do
    case Repo.get(TrainingJob, training_job_id) do
      nil ->
        Logger.error("Training job not found: #{training_job_id}")
        {:error, :job_not_found}

      %TrainingJob{status: "pending"} = job ->
        execute_training_job(job)

      %TrainingJob{status: status} = job ->
        Logger.warning("Training job #{training_job_id} is not pending (status: #{status})")
        :ok
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_type" => "fine_tune", "config" => config}}) do
    create_and_execute_fine_tune_job(config)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_type" => "distillation", "config" => config}}) do
    create_and_execute_distillation_job(config)
  end

  def enqueue_training_job(training_job_id) do
    %{training_job_id: training_job_id}
    |> new()
    |> Oban.insert()
  end

  def enqueue_fine_tune_job(config) do
    %{job_type: "fine_tune", config: config}
    |> new()
    |> Oban.insert()
  end

  def enqueue_distillation_job(config) do
    %{job_type: "distillation", config: config}
    |> new()
    |> Oban.insert()
  end

  def create_training_job(job_type, config \\ %{}) do
    job = %TrainingJob{
      id: UUID.uuid4(),
      status: "pending",
      job_type: job_type,
      config: config,
      progress_percentage: 0.0
    }

    case Repo.insert(job) do
      {:ok, job} ->
        enqueue_training_job(job.id)
        {:ok, job}

      error ->
        error
    end
  end

  # Private functions

  defp execute_training_job(job) do
    Logger.info("Starting training job: #{job.id} (type: #{job.job_type})")

    # Update job status to running
    job = update_job_status(job, "running", %{started_at: DateTime.utc_now()})

    try do
      case job.job_type do
        "fine_tune" ->
          execute_fine_tune(job)

        "distillation" ->
          execute_distillation(job)

        "embedding" ->
          execute_embedding_training(job)

        _ ->
          {:error, :unknown_job_type}
      end
    rescue
      error ->
        Logger.error("Training job #{job.id} failed with error: #{inspect(error)}")
        update_job_status(job, "failed", %{
          error_message: inspect(error),
          completed_at: DateTime.utc_now()
        })
        {:error, error}
    end
  end

  defp execute_fine_tune(job) do
    Logger.info("Executing fine-tune job: #{job.id}")

    with {:ok, dataset} <- prepare_training_dataset(job),
         {:ok, model_config} <- prepare_model_config(job),
         {:ok, training_results} <- run_fine_tuning(dataset, model_config, job) do

      update_job_status(job, "completed", %{
        results: training_results,
        completed_at: DateTime.utc_now(),
        progress_percentage: 100.0
      })

      Logger.info("Fine-tune job #{job.id} completed successfully")
      :ok
    else
      {:error, reason} ->
        update_job_status(job, "failed", %{
          error_message: inspect(reason),
          completed_at: DateTime.utc_now()
        })
        {:error, reason}
    end
  end

  defp execute_distillation(job) do
    Logger.info("Executing distillation job: #{job.id}")

    with {:ok, teacher_responses} <- collect_teacher_responses(job),
         {:ok, student_dataset} <- prepare_distillation_dataset(teacher_responses, job),
         {:ok, distillation_results} <- run_distillation(student_dataset, job) do

      update_job_status(job, "completed", %{
        results: distillation_results,
        completed_at: DateTime.utc_now(),
        progress_percentage: 100.0
      })

      Logger.info("Distillation job #{job.id} completed successfully")
      :ok
    else
      {:error, reason} ->
        update_job_status(job, "failed", %{
          error_message: inspect(reason),
          completed_at: DateTime.utc_now()
        })
        {:error, reason}
    end
  end

  defp execute_embedding_training(job) do
    Logger.info("Executing embedding training job: #{job.id}")

    # This would train custom embeddings on domain-specific data
    # For now, we'll simulate the process
    simulate_training_progress(job, 1000)

    update_job_status(job, "completed", %{
      results: %{
        embedding_model: "custom-v1",
        training_samples: 10000,
        validation_accuracy: 0.92
      },
      completed_at: DateTime.utc_now(),
      progress_percentage: 100.0
    })

    Logger.info("Embedding training job #{job.id} completed successfully")
    :ok
  end

  defp prepare_training_dataset(job) do
    import Ecto.Query

    limit = get_in(job.config, ["dataset_limit"]) || 1000

    # Get successful query logs for training
    training_data =
      from(q in QueryLog,
        where: q.used_for_training == false and not is_nil(q.feedback_score),
        where: q.feedback_score >= 4,  # Only use highly rated responses
        order_by: [desc: q.inserted_at],
        limit: ^limit
      )
      |> Repo.all()

    if length(training_data) < 10 do
      {:error, :insufficient_training_data}
    else
      # Mark data as used for training
      training_ids = Enum.map(training_data, & &1.id)

      from(q in QueryLog, where: q.id in ^training_ids)
      |> Repo.update_all(set: [used_for_training: true])

      dataset = format_training_dataset(training_data)
      {:ok, dataset}
    end
  end

  defp prepare_model_config(job) do
    default_config = %{
      model_name: "neural-bridge-ft",
      learning_rate: 0.0001,
      epochs: 3,
      batch_size: 4,
      validation_split: 0.2
    }

    config = Map.merge(default_config, job.config)
    {:ok, config}
  end

  defp run_fine_tuning(dataset, model_config, job) do
    Logger.info("Starting fine-tuning with #{length(dataset)} samples")

    # Simulate fine-tuning process
    total_steps = model_config.epochs * 100
    simulate_training_progress(job, total_steps)

    # Mock training results
    results = %{
      model_id: "ft-#{UUID.uuid4()}",
      training_samples: length(dataset),
      validation_loss: 0.15,
      training_loss: 0.12,
      epochs_completed: model_config.epochs,
      total_training_time_minutes: Enum.random(30..120)
    }

    {:ok, results}
  end

  defp collect_teacher_responses(job) do
    import Ecto.Query

    limit = get_in(job.config, ["sample_limit"]) || 500

    # Collect high-quality API B responses
    teacher_data =
      from(q in QueryLog,
        where: q.source == "api_b" and q.confidence_score >= 0.8,
        order_by: [desc: q.inserted_at],
        limit: ^limit
      )
      |> Repo.all()

    if length(teacher_data) < 50 do
      {:error, :insufficient_teacher_data}
    else
      {:ok, teacher_data}
    end
  end

  defp prepare_distillation_dataset(teacher_responses, _job) do
    dataset =
      teacher_responses
      |> Enum.map(fn response ->
        %{
          input: response.query,
          teacher_output: response.response,
          metadata: response.metadata
        }
      end)

    {:ok, dataset}
  end

  defp run_distillation(dataset, job) do
    Logger.info("Starting distillation with #{length(dataset)} teacher examples")

    # Simulate distillation process
    total_steps = 500
    simulate_training_progress(job, total_steps)

    results = %{
      student_model_id: "distill-#{UUID.uuid4()}",
      teacher_examples: length(dataset),
      distillation_loss: 0.08,
      knowledge_retention: 0.89,
      compression_ratio: 0.3,
      total_training_time_minutes: Enum.random(60..180)
    }

    {:ok, results}
  end

  defp simulate_training_progress(job, total_steps) do
    step_size = max(1, div(total_steps, 20))  # Update progress 20 times

    for step <- step_size..total_steps//step_size do
      progress = (step / total_steps) * 100

      job
      |> Ecto.Changeset.change(%{progress_percentage: progress})
      |> Repo.update()

      # Emit training metrics
      :telemetry.execute(
        [:neural_bridge, :training, :progress],
        %{progress_percentage: progress},
        %{job_id: job.id, job_type: job.job_type}
      )

      Process.sleep(1000)  # Simulate training time
    end
  end

  defp format_training_dataset(query_logs) do
    query_logs
    |> Enum.map(fn log ->
      %{
        messages: [
          %{role: "user", content: log.query},
          %{role: "assistant", content: log.response}
        ],
        metadata: %{
          source: log.source,
          confidence_score: log.confidence_score,
          feedback_score: log.feedback_score
        }
      }
    end)
  end

  defp update_job_status(job, status, additional_fields \\ %{}) do
    fields = Map.put(additional_fields, :status, status)

    job
    |> Ecto.Changeset.change(fields)
    |> Repo.update!()
  end

  defp create_and_execute_fine_tune_job(config) do
    case create_training_job("fine_tune", config) do
      {:ok, job} ->
        execute_training_job(job)

      error ->
        error
    end
  end

  defp create_and_execute_distillation_job(config) do
    case create_training_job("distillation", config) do
      {:ok, job} ->
        execute_training_job(job)

      error ->
        error
    end
  end
end