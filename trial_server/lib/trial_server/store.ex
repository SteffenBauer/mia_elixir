defmodule TrialServer.Store do

  require Logger

  def init() do
    Process.register(self(), __MODULE__)
    trial_table = :"#{__MODULE__}"
    :ets.new(trial_table, [:set, :public])
  end

  def print_store() do
    store = Agent.get(__MODULE__, &(&1))
    print_store(store, :ets.first(store))
  end
  def print_store(_store, :"$end_of_table"), do: nil
  def print_store(store, entry) do
    Logger.debug("#{inspect entry} -> #{inspect :ets.lookup(store, entry)}")
    print_store(store, :ets.next(store, entry))
  end

  def addr_in_store?(addr, port) do
    Agent.get(__MODULE__, &(&1))
    |> addr_in_store?(addr, port)
  end
  def addr_in_store?(store, addr, port) do
    addr_in_store?(store, addr, port, :ets.first(store))
  end
  def addr_in_store?(_store, _addr, _port, :"$end_of_table"), do: false
  def addr_in_store?(store, addr, port, entry) do
    case :ets.lookup(store, entry) do
      [{_, %{:addr => ^addr, :port => ^port}}] -> true
      _other -> addr_in_store?(store, addr, port, :ets.next(store, entry))
    end
  end

  def put_trial(trial) do
    Agent.get(__MODULE__, &(&1))
    |> :ets.insert({trial.uuid, trial})
  end

  def pop_trial(uuid) do
    case Agent.get(__MODULE__, &(&1)) |> :ets.take(uuid) do
      [] -> nil
      [{_, trial}] -> trial
    end
  end

end
