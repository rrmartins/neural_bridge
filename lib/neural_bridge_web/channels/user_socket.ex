defmodule NeuralBridgeWeb.UserSocket do
  use Phoenix.Socket

  # Define channels and their routes
  channel "proxy:*", NeuralBridgeWeb.ProxyChannel

  # Socket params are passed from the client and can be used to verify and authenticate a user.
  @impl true
  def connect(params, socket, _connect_info) do
    # Perform authentication and authorization here
    # For development, we'll allow all connections
    socket = assign(socket, :user_id, params["user_id"])
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end