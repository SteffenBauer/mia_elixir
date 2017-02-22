defmodule TrialServer do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Task, [TrialServer.UDP, :accept, []]),
      worker(Agent, [TrialServer.Store, :init, []])
    ]

    opts = [strategy: :one_for_one, name: TrialServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
