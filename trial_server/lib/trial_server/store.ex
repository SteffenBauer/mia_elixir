defmodule TrialServer.Store do

  require Logger

  defstruct addr: nil, port: nil, uuid: nil,
            solution: nil, trials: 5, correct: 0, wrong: 0

  def init() do
    Process.register(self(), __MODULE__)
    Logger.debug("TrialServer Store started")
    []
  end

  def print_store() do
    Logger.debug("In store now: #{inspect Agent.get(__MODULE__, &(&1))}")
  end

  def addr_in_store?(addr, port) do
    Agent.get(__MODULE__, fn e -> Enum.any?(e, &(&1.addr == addr and &1.port == port)) end)
  end

  def new_trial(addr, port, uuid, solution) do
    Agent.update(__MODULE__, &(&1 ++ [%TrialServer.Store{addr: addr, port: port, uuid: uuid, solution: solution}]))
  end

  def update_trial(uuid, solution) do
    Agent.update(__MODULE__, &(Enum.map(&1, fn t -> update_values(t, uuid, solution) end)))
  end

  defp update_values(t, uuid, solution) do
    case {t.uuid, t.solution} do
      {^uuid, ^solution} -> %TrialServer.Store{t | trials: t.trials - 1, correct: t.correct + 1}
      {^uuid, _}         -> %TrialServer.Store{t | trials: t.trials - 1, wrong: t.wrong + 1}
      {_,     _}         -> t
    end
  end

end
