defmodule TrialServer.Store do

  require Logger

  defstruct addr: nil, port: nil, uuid: nil,
            solution: nil, trials: nil, correct: 0, wrong: 0

  def init() do
    Logger.debug("TrialServer Store started")
    []
  end

  def addr_in_store?(addr) do
    Agent.get(__MODULE__, fn e -> Enum.any?(e, &(&1.addr == addr)) end)
  end

  def new_trial(addr, port, uuid, solution) do

  end
end
