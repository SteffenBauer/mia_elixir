defmodule TrialServer.Store do

  require Logger

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

  def put_trial(trial) do
    Agent.update(__MODULE__, &(&1 ++ [trial]))
  end

  def pop_trial(uuid) do
    {trials, store} = Agent.get(__MODULE__, &(Enum.split_with(&1, fn t -> t.uuid == uuid end)))
    Agent.update(__MODULE__, fn _ -> store end)
    trials
  end

end
