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

  def invalid(ip, port, msg) do
    GenServer.cast(__MODULE__, {:invalid, ip, port, msg})
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA game machine"
    Process.send_after(self(), :check_registry, @timeout)
    {:ok, %{:state => :waiting, :round => 1, :playerno => 0, :token => nil, :action => nil}}
  end

  def handle_cast({:join, ip, port, token}, %{:state => :wait_for_joins} = state) do
    MiaServer.Playerlist.join_player(ip, port, token)
    {:noreply, state}
  end

  def handle_cast({:player_rolls, token}, %{:state => :round, :token => token} = state) do
    {:noreply, %{state | :action => :rolls}}
  end

  def handle_cast({:invalid, ip, _port, _msg}, %{:state => :round} = state) do
    {ipp, _portp, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    if ip == ipp do
      broadcast_message("PLAYER LOST;#{name};INVALID TURN")
      update_score(state.playerno, :lost)
      get_scoremsg() |> broadcast_message()
      Process.send_after(self(), :check_registry, @timeout)
      {:noreply, %{state | :state => :waiting, :round => state.round+1, :playerno => 0, :token => nil, :action => nil}}
    else
      {:noreply, state}
    end
  end

  def handle_info(:check_registry, %{:state => :waiting} = state) do
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
    nextstate = cond do
      length(registered_players) > 1 ->
        send_invitations(registered_participants)
        Process.send_after(self(), :check_joins, @timeout)
        :wait_for_joins
      true ->
        Process.send_after(self(), :check_registry, @timeout)
        :waiting
    end
    {:noreply, %{state | :state => nextstate}}
  end

  def handle_info(:check_joins, %{:state => :wait_for_joins} = state) do
    joined_players = MiaServer.Playerlist.get_joined_players()
    {reply, state, next} = case length(joined_players) do
      0 -> {"ROUND CANCELED;NO PLAYERS", %{state | :state => :waiting}, :check_registry}
      1 -> {"ROUND CANCELED;ONLY ONE PLAYER", %{state | :state => :waiting}, :check_registry}
      _ -> playerlist = generate_playerlist(joined_players)
             |> store_playerlist()
             |> playerstring()
           {"ROUND STARTED;#{state.round};#{playerlist}", %{state | :state => :round, :playerno => 0}, :send_your_turn}
    end
    broadcast_message(reply)
    Process.send_after(self(), next, @timeout)
    {:noreply, state}
  end

  def handle_info(:send_your_turn, %{:state => :round} = state) do
    {ip, port, _name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    token = uuid()
    MiaServer.UDP.reply(ip, port, "YOUR TURN;#{token}")
    Process.send_after(self(), :check_action, @timeout)
    {:noreply, %{state | :token => token, :action => nil}}
  end

  def handle_info(:check_action, %{:state => :round, :action => :rolls} = state) do
    {ip, port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER ROLLS;#{name}")
    dice = MiaServer.DiceRoller.roll()
    token = uuid()
    reply = "ROLLED;#{dice};#{token}"
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, %{state | :token => token}}
  end

  def handle_info(:check_action, %{:state => :round, :action => nil} = state) do
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER LOST;#{name};DID NOT TAKE TURN")
    update_score(state.playerno, :lost)
    get_scoremsg() |> broadcast_message()
    Process.send_after(self(), :check_registry, @timeout)
    {:noreply, %{state | :state => :waiting, :round => state.round+1, :playerno => 0, :token => nil, :action => nil}}
  end

## Private helper functions

  defp broadcast_message(msg) do
    MiaServer.Registry.get_registered()
      |> Enum.each(fn [ip, port, _role] -> MiaServer.UDP.reply(ip, port, msg) end)
  end

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
      |> Enum.filter(fn [ip, port, _name, _score] -> [ip, port] in players end)
      |> Enum.shuffle
  end

  defp store_playerlist(playerlist) do
    MiaServer.Playerlist.flush()
    playerlist
      |> Enum.reduce(0, fn [ip, port, name, _score], num ->
        MiaServer.Playerlist.add_participating_player(num, ip, port, name)
        num+1 end)
    playerlist
  end

  defp playerstring(playerlist) do
    playerlist
      |> Enum.map(fn [_ip, _port, name, _score] -> name end)
      |> Enum.join(",")
  end

  defp update_score(playerno, :lost) do
    for pn <- 0..MiaServer.Playerlist.get_participating_number()-1, pn != playerno do
      {_i, _p, name} = MiaServer.Playerlist.get_participating_player(pn)
      MiaServer.Registry.increase_score(name)
    end
  end

  defp update_score(playerno, :won) do
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(playerno)
    MiaServer.Registry.increase_score(name)
  end

  defp get_scoremsg() do
    scores = MiaServer.Registry.get_players()
      |> Enum.map(fn [_ip, _port, name, score] -> "#{name}:#{score}" end)
      |> Enum.sort()
      |> Enum.join(",")
    "SCORE;" <> scores
  end
end
