defmodule MiaServer.Playerlist do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

## API

  def flush() do
    GenServer.cast(__MODULE__, :flush)
  end

  def add_invited_player(ip, port, token) do
    GenServer.cast(__MODULE__, {:add, ip, port, token})
  end

  def join_player(ip, port, token) do
    GenServer.cast(__MODULE__, {:join, ip, port, token})
  end

  def get_joined_players() do
    GenServer.call(__MODULE__, :get_joined)
  end

  def add_participating_player(num, ip, port, name) do
    GenServer.cast(__MODULE__, {num, :playing, ip, port, name})
  end

  def get_participating_player(num) do
    GenServer.call(__MODULE__, {:get_player, num})
  end

  def get_participating_number() do
    GenServer.call(__MODULE__, :get_num)
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA registry for round players"
    players_table = :"#{__MODULE__}"
    players = :ets.new(players_table, [:set, :private])
    {:ok, players}
  end

  def handle_cast(:flush, players) do
    :ets.delete_all_objects(players)
    {:noreply, players}
  end

  def handle_cast({:add, ip, port, token}, players) do
    :ets.insert(players, {ip, port, token})
    {:noreply, players}
  end

  def handle_cast({:join, ip, port, token}, players) do
    if :ets.match(players, {ip, port, token}) != [] do
      :ets.insert(players, {ip, port, :joined})
    end
    {:noreply, players}
  end

  def handle_cast({num, :playing, ip, port, name}, players) do
    :ets.insert(players, {num, ip, port, name})
    {:noreply, players}
  end

  def handle_call(:get_joined, _from, players) do
    joined = :ets.match(players, {:"$1", :"$2", :joined})
    {:reply, joined, players}
  end

  def handle_call({:get_player, num}, _from, players) do
    [{^num, ip, port, name} | _] = :ets.lookup(players, num)
    {:reply, {ip, port, name}, players}
  end

  def handle_call(:get_num, _from, players) do
    num = :ets.info(players, :size)
    {:reply, num, players}
  end

end
