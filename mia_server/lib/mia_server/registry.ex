defmodule MiaServer.Registry do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

## API

  def register_player(ip, port, name) do
    GenServer.cast(__MODULE__, {ip, port, name})
  end

  def register_spectator(ip, port) do
    GenServer.cast(__MODULE__, {ip, port})
  end

  def get_players() do
    GenServer.call(__MODULE__, :players)
  end

  def get_registered() do
    GenServer.call(__MODULE__, :registered)
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA participants registry"
    participants_table = :"#{__MODULE__}"
    registry = :ets.new(participants_table, [:set, :private])
    {:ok, registry}
  end

  def handle_cast({ip, port, name}, registry) do
    reply = cond do
      name |> String.length > 20 -> "REJECTED"
      name |> String.contains?([" ", ";", ","]) -> "REJECTED"
      registry |> :ets.member(ip) -> "ALREADY REGISTERED"
      registry |> :ets.match({:"$1", :"_", {:player, name}}) != [] -> "REJECTED"
      true -> "REGISTERED"
    end
    if (reply =~ "REGISTERED"), do: :ets.insert(registry, {ip, port, {:player, name}})
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, registry}
  end

  def handle_cast({ip, port}, registry) do
    reply = cond do
      registry |> :ets.member(ip) -> "ALREADY REGISTERED"
      true -> "REGISTERED"
    end
    :ets.insert(registry, {ip, port, :spectator})
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, registry}
  end

  def handle_call(:players, _from, registry) do
    players = :ets.match(registry, {:"$1", :"$2", {:player, :"$3"}})
    {:reply, players, registry}
  end

  def handle_call(:registered, _from, registry) do
    registered = :ets.match(registry, {:"$1", :"$2", :"_"})
    {:reply, registered, registry}
  end

end
