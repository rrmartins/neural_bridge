defmodule NeuralBridge.Repo.Migrations.EnablePgvectorExtension do
  use Ecto.Migration

  def change do
    # Skip pgvector extension for now - can be added later when vector support is configured
    # execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"
  end
end
