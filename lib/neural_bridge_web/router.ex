defmodule NeuralBridgeWeb.Router do
  use NeuralBridgeWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", NeuralBridgeWeb do
    pipe_through :api

    # LLM Proxy endpoints
    post "/proxy/query", ProxyController, :query
    get "/proxy/health", ProxyController, :health
    get "/proxy/stats", ProxyController, :stats

    # Conversation management
    get "/conversations/:session_id", ConversationController, :show
    get "/conversations/:session_id/history", ConversationController, :history
    delete "/conversations/:session_id", ConversationController, :delete

    # Knowledge base management
    post "/knowledge/ingest", KnowledgeController, :ingest
    get "/knowledge/documents", KnowledgeController, :list_documents
    get "/knowledge/documents/:source_document", KnowledgeController, :show_document
    delete "/knowledge/documents/:source_document", KnowledgeController, :delete_document
    post "/knowledge/documents/:source_document/reprocess", KnowledgeController, :reprocess_document

    # Training management
    post "/training/jobs", TrainingController, :create_job
    get "/training/jobs", TrainingController, :list_jobs
    get "/training/jobs/:job_id", TrainingController, :show_job
    delete "/training/jobs/:job_id", TrainingController, :cancel_job

    # Cache management
    get "/cache/stats", CacheController, :stats
    delete "/cache", CacheController, :clear
    delete "/cache/expired", CacheController, :cleanup

    # Admin endpoints
    get "/admin/system", AdminController, :system_info
    get "/admin/metrics", AdminController, :metrics
  end


  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:neural_bridge, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: NeuralBridgeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
