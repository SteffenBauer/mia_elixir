defmodule MiaServer do
  @moduledoc """
  Documentation for MiaServer.
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: MiaServer.Worker.start_link(arg1, arg2, arg3)
      # worker(MiaServer.Worker, [arg1, arg2, arg3]),
    ]

    opts = [strategy: :one_for_one, name: MiaServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
