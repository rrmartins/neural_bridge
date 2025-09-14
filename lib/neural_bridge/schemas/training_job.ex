defmodule NeuralBridge.Schemas.TrainingJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "training_jobs" do
    field :status, :string
    field :job_type, :string
    field :dataset_size, :integer
    field :progress_percentage, :float, default: 0.0
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_message, :string
    field :config, :map, default: %{}
    field :results, :map, default: %{}

    timestamps()
  end

  def changeset(training_job, attrs) do
    training_job
    |> cast(attrs, [
      :status,
      :job_type,
      :dataset_size,
      :progress_percentage,
      :started_at,
      :completed_at,
      :error_message,
      :config,
      :results
    ])
    |> validate_required([:status, :job_type])
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed"])
    |> validate_inclusion(:job_type, ["embedding", "fine_tune", "distillation"])
    |> validate_number(:progress_percentage, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
  end
end