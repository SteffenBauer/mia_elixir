defmodule MiaServer.Game do
  use GenServer
  require Logger

  defstruct state: :waiting,
            round: 1,
            playerno: nil,
            token: nil,
            action: nil,
            timer: nil,
            dice: nil,
            announced: nil

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

  def do_announce(d1, d2, token) do
    GenServer.cast(__MODULE__, {:player_announces, d1, d2, token})
  end

  def do_see(token) do
    GenServer.cast(__MODULE__, {:player_sees, token})
  end

  def invalid(ip, port, msg) do
    GenServer.cast(__MODULE__, {:invalid, ip, port, msg})
  end

  def testing_inject_dice(dice) do
    GenServer.cast(__MODULE__, {:inject, dice})
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA game machine"
    {:ok, %MiaServer.Game{:timer => Process.send_after(self(), :check_registry, @timeout)} }
  end

  def handle_cast({:inject, dice}, state) do
    {:noreply, %{state | :dice => dice}}
  end

  def handle_cast({:join, ip, port, token}, %{:state => :wait_for_joins} = state) do
    MiaServer.Playerlist.join_player(ip, port, token)
    {:noreply, state}
  end

  def handle_cast({:player_rolls, token}, %{:state => :round, :token => token} = state) do
    {:noreply, %{state | :action => :rolls}}
  end

  def handle_cast({:player_sees, token}, %{:token => token} = state) do
    {:noreply, state}
  end

  def handle_cast({:player_announces, _, _, token}, %{:token => token, :dice => nil} = state) do
    {:noreply, player_lost_aftermath(state, "INVALID TURN")}
  end

  def handle_cast({:player_announces, d1, d2, token}, %{:state => :wait_for_announce, :token => token} = state) do
    case MiaServer.Dice.new(d1, d2) do
      :invalid ->
        {:noreply, player_lost_aftermath(state, "INVALID TURN")}
      dice ->
        {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
        broadcast_message("ANNOUNCED;#{name};#{dice}")
        {:noreply, %{state | :announced => dice}}
    end
  end

  def handle_cast({:invalid, ip, _port, _msg}, %{:state => :round} = state) do
    {ipp, _portp, _name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    {:noreply, if(ip == ipp, do: player_lost_aftermath(state, "INVALID TURN"), else: state)}
  end

  def handle_info(:check_registry, %{:state => :waiting} = state) do
    Process.cancel_timer(state.timer)
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
    {nextstate, timer} = cond do
      length(registered_players) > 1 ->
        send_invitations(registered_participants)
        {:wait_for_joins, Process.send_after(self(), :check_joins, @timeout)}
      true ->
        {:waiting, Process.send_after(self(), :check_registry, @timeout)}
    end
    {:noreply, %{state | :state => nextstate, :timer => timer}}
  end

  def handle_info(:check_joins, %{:state => :wait_for_joins} = state) do
    Process.cancel_timer(state.timer)
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
    {:noreply, %{state | :timer => Process.send_after(self(), next, @timeout)}}
  end

  def handle_info(:send_your_turn, %{:state => :round} = state) do
    Process.cancel_timer(state.timer)
    {ip, port, _name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    token = uuid()
    MiaServer.UDP.reply(ip, port, "YOUR TURN;#{token}")
    {:noreply, %{state | :token => token,
                         :action => nil,
                         :timer => Process.send_after(self(), :check_action, @timeout)}}
  end

  def handle_info(:check_action, %{:state => :round, :action => :rolls} = state) do
    Process.cancel_timer(state.timer)
    {ip, port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER ROLLS;#{name}")
    dice = MiaServer.DiceRoller.roll()
    token = uuid()
    reply = "ROLLED;#{dice};#{token}"
    MiaServer.UDP.reply(ip, port, reply)
    {:noreply, %{state | :state => :wait_for_announce,
                         :token => token,
                         :action => nil,
                         :dice => dice,
                         :timer => Process.send_after(self(), :check_announcement, @timeout)}}
  end

  def handle_info(:check_action, %{:state => :round, :action => nil} = state) do
    {:noreply, player_lost_aftermath(state, "DID NOT TAKE TURN")}
  end

  def handle_info(:check_announcement, %{:state => :wait_for_announce, :action => nil} = state) do
    {:noreply, player_lost_aftermath(state, "DID NOT ANNOUNCE")}
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

  defp player_lost_aftermath(state, reason) do
    Process.cancel_timer(state.timer)
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER LOST;#{name};#{reason}")
    update_score(state.playerno, :lost)
    get_scoremsg() |> broadcast_message()
    %MiaServer.Game{:round => state.round+1, :timer => Process.send_after(self(), :check_registry, @timeout)}
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
