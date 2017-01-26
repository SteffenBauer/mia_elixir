defmodule EchoServer do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Starts a worker by calling: EchoServer.Worker.start_link(arg1, arg2, arg3)
      # worker(EchoServer.Worker, [arg1, arg2, arg3]),
    ]

    opts = [strategy: :one_for_one, name: EchoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
