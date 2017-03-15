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

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA participants registry"
    participants_table = :"#{__MODULE__}"
    registry = :ets.new(participants_table, [:set, :private])
    {:ok, registry}
  end

  def handle_cast({ip, port, name}, registry) do
    :ets.insert(registry, {ip, port, :player, name})
    MiaServer.UDP.reply(ip, port, "REGISTERED")
    {:noreply, registry}
  end

  def handle_cast({ip, port}, registry) do
    :ets.insert(registry, {ip, port, :spectator})
    MiaServer.UDP.reply(ip, port, "REGISTERED")
    {:noreply, registry}
  end

end
