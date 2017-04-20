defmodule MiaServer.Game do
  use GenServer
  require Logger

  @timeout Application.get_env(:mia_server, :timeout)

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

## API

  def register_join(ip, port, token) do
    GenServer.cast(__MODULE__, {:join, ip, port, token})
  end

  def do_roll(token) do
    GenServer.cast(__MODULE__, {:player_rolls, token})
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA game machine"
    Process.send_after(self(), :check_registry, @timeout)
    {:ok, {:waiting, 0, 1}}
  end

  def handle_cast({:join, ip, port, token}, {:wait_for_joins, playerno, roundno}) do
    MiaServer.Playerlist.join_player(ip, port, token)
    {:noreply, {:wait_for_joins, playerno, roundno}}
  end
  def handle_cast({:join, _ip, _port, _token}, {state, playerno, roundno}) do
    {:noreply, {state, playerno, roundno}}
  end

  def handle_cast({:player_rolls, token}, {:round, {playerno, token}, roundno}) do
    {:noreply, {:round, {playerno, :rolls}, roundno}}
  end

  def handle_info(:check_registry, {:waiting, _, roundno}) do
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
    state = cond do
      length(registered_players) > 1 ->
        send_invitations(registered_participants)
        Process.send_after(self(), :check_joins, @timeout)
        :wait_for_joins
      true ->
        Process.send_after(self(), :check_registry, @timeout)
        :waiting
    end
    {:noreply, {state, 0, roundno}}
  end

  def handle_info(:check_joins, {:wait_for_joins, _, roundno}) do
    joined_players = MiaServer.Playerlist.get_joined_players()
    {reply, state, next} = case length(joined_players) do
      0 -> {"ROUND CANCELED;NO PLAYERS", :waiting, :check_registry}
      1 -> {"ROUND CANCELED;ONLY ONE PLAYER", :waiting, :check_registry}
      _ -> playerlist = generate_playerlist(joined_players)
             |> store_playerlist()
             |> playerstring()
           {"ROUND STARTED;#{roundno};#{playerlist}", :round, :send_your_turn}
    end
    MiaServer.Registry.get_registered()
      |> Enum.each(fn [ip, port, _role] -> MiaServer.UDP.reply(ip, port, reply) end)
    Process.send_after(self(), next, @timeout)
    {:noreply, {state, 0, roundno}}
  end

  def handle_info(:send_your_turn, {:round, playerno, roundno}) do
    {ip, port, name} = MiaServer.Playerlist.get_participating_player(playerno)
    token = uuid()
    MiaServer.UDP.reply(ip, port, "YOUR TURN;#{token}")
    Process.send_after(self(), :check_action, @timeout)
    {:noreply, {:round, {playerno, token}, roundno}}
  end

  def handle_info(:check_action, {:round, {playerno, :rolls}, roundno}) do
    {ip, port, _name} = MiaServer.Playerlist.get_participating_player(playerno)
    dice = MiaServer.DiceRoller.roll()
    token = uuid()
    reply = "ROLLED;#{dice};#{token}"
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, {:round, playerno, roundno}}
  end
  def handle_info(:check_action, {:round, {playerno, _}, roundno}) do
    {:noreply, {:round, playerno, roundno}}
  end

## Private helper functions

  defp send_invitations(participants) do
    MiaServer.Playerlist.flush()
    participants
      |> Enum.map(fn [ip, port, role] -> generate_invitation(ip, port, role) end)
      |> Enum.each(fn {ip, port, msg} -> MiaServer.UDP.reply(ip, port, msg) end)
  end

  defp generate_invitation(ip, port, :player) do
    token = uuid()
    MiaServer.Playerlist.add_invited_player(ip, port, token)
    {ip, port, "ROUND STARTING;"<>token}
  end
  defp generate_invitation(ip, port, :spectator) do
    {ip, port, "ROUND STARTING"}
  end

  defp uuid() do
    for _ <- 1..32 do
      :rand.uniform(16)-1
      |> Integer.to_string(16)
    end
    |> Enum.join
  end

  defp generate_playerlist(players) do
    MiaServer.Registry.get_players()
      |> Enum.filter(fn [ip, port, _name] -> [ip, port] in players end)
      |> Enum.shuffle
  end

  defp store_playerlist(playerlist) do
    MiaServer.Playerlist.flush()
    playerlist
      |> Enum.reduce(0, fn [ip, port, name], num ->
        MiaServer.Playerlist.add_participating_player(num, ip, port, name)
        num+1 end)
    playerlist
  end

  defp playerstring(playerlist) do
    playerlist
      |> Enum.map(fn [_ip, _port, name] -> name end)
      |> Enum.join(",")
  end

end
