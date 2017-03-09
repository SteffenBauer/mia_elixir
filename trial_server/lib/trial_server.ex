defmodule TrialServer do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Registry, [:unique, Registry.Trial]),
      worker(Agent, [TrialServer.Store, :init, []]),
      supervisor(Task.Supervisor, [[name: TrialServer.TaskSupervisor]]),
      worker(TrialServer.UDP, [])
    ]

    opts = [strategy: :one_for_one, name: TrialServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
