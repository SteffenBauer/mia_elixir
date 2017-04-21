defmodule MiaServer.Registry do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

## API

  def register_player(ip, port, name) do
    GenServer.cast(__MODULE__, {:register, ip, port, name})
  end

  def register_spectator(ip, port) do
    GenServer.cast(__MODULE__, {:register, ip, port})
  end

  def get_players() do
    GenServer.call(__MODULE__, :players)
  end

  def get_registered() do
    GenServer.call(__MODULE__, :registered)
  end

  def increase_score(name) do
    GenServer.cast(__MODULE__, {:incrscore, name})
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA participants registry"
    participants_table = :"#{__MODULE__}"
    registry = :ets.new(participants_table, [:set, :private])
    {:ok, registry}
  end

  def handle_cast({:register, ip, port, name}, registry) do
    reply = player_reply(name, ip, registry)
    if (reply =~ "REGISTERED") do
      :ets.insert(registry, {ip, port, {:player, name, 0}})
    end
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, registry}
  end

  def handle_cast({:register, ip, port}, registry) do
    reply = spectator_reply(ip, registry)
    :ets.insert(registry, {ip, port, {:spectator, nil, nil}})
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, registry}
  end

  def handle_cast({:incrscore, name}, registry) do
    entry = registry |> :ets.match({:"$1", :"$2", {:player, name, :"$3"}})
    case entry do
      [[ip, port, score]] -> registry |> :ets.insert({ip, port, {:player, name, score+1}})
    end
    {:noreply, registry}
  end

  def handle_call(:players, _from, registry) do
    players = :ets.match(registry, {:"$1", :"$2", {:player, :"$3", :"$4"}})
    {:reply, players, registry}
  end

  def handle_call(:registered, _from, registry) do
    registered = :ets.match(registry, {:"$1", :"$2", {:"$3", :"_", :"_"}})
    {:reply, registered, registry}
  end

## Private helper functions

  defp player_reply(name, ip, registry) do
    cond do
      name |> String.length > 20 -> "REJECTED"
      name |> String.contains?([" ", ";", ","]) -> "REJECTED"
      registry |> :ets.member(ip) -> "ALREADY REGISTERED"
      registry |> :ets.match({:"$1", :"_", {:player, name, :"_"}}) != [] -> "REJECTED"
      true -> "REGISTERED"
    end
  end

  defp spectator_reply(ip, registry) do
    cond do
      registry |> :ets.member(ip) -> "ALREADY REGISTERED"
      true -> "REGISTERED"
    end
  end

end
