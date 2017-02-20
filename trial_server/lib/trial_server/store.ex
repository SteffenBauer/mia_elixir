defmodule TrialServer.Store do

  require Logger

  defstruct addr: nil, port: nil, uuid: nil,
            solution: nil, trials: 5, correct: 0, wrong: 0

  def init() do
    Process.register(self(), __MODULE__)
    Logger.debug("TrialServer Store started")
    []
  end

  def addr_in_store?(addr) do
    Agent.get(__MODULE__, fn e -> Enum.any?(e, &(&1.addr == addr)) end)
  end

  def new_trial(addr, port, uuid, solution) do
    Agent.update(__MODULE__, &(&1 ++ [%TrialServer.Store{addr: addr, port: port, uuid: uuid, solution: solution}]))
    Logger.debug("In store now: #{inspect Agent.get(__MODULE__, &(&1))}")
  end

end
