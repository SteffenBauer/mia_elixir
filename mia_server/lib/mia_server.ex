defmodule MiaServer do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(MiaServer.Registry, []),
      worker(MiaServer.UDP, [])
    ]

    opts = [strategy: :one_for_one, name: MiaServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
