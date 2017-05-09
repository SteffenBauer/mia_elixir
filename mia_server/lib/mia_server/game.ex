defmodule MiaServer.Game do
  use GenServer
  require Logger

  defstruct state: :wait_for_registrations,
            round: 1,
            playerno: nil,
            token: nil,
            action: nil,
            timer: nil,
            dice: nil,
            announced: nil,
            injected: nil

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

  def testing_inject_dice(d1, d2) do
    GenServer.cast(__MODULE__, {:inject, d1, d2})
  end

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA game machine"
    {:ok, %MiaServer.Game{:timer => Process.send_after(self(), :check_registry, @timeout)} }
  end

  def handle_cast({:join, ip, port, token}, %{:state => :wait_for_joins} = state) do
    MiaServer.Playerlist.join_player(ip, port, token)
    {:noreply, state}
  end

  def handle_cast({:player_sees, token}, %{:state => :round, :token => token} = state) do
    Process.cancel_timer(state.timer)
    {:noreply, handle_see(state)}
  end

  def handle_cast({:player_rolls, token}, %{:state => :round, :token => token} = state) do
    {:noreply, %{state | :action => :rolls}}
  end

  def handle_cast({:player_announces, _, _, token}, %{:token => token, :dice => nil} = state) do
    {:noreply, player_lost_aftermath(state, "INVALID TURN")}
  end

  def handle_cast({:player_announces, d1, d2, token}, %{:state => :wait_for_announce, :token => token} = state) do
    Process.cancel_timer(state.timer)
    {:noreply, handle_announce(state, d1, d2)}
  end

  def handle_cast({:invalid, ip, _port, _msg}, %{:state => :round} = state) do
    {ipp, _portp, _name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    {:noreply, if(ip == ipp, do: player_lost_aftermath(state, "INVALID TURN"), else: state)}
  end

  def handle_cast({:inject, d1, d2}, state) do
    Logger.debug("Inject: Next die roll will be #{d1},#{d2}")
    {:noreply, %{state | :injected => MiaServer.Dice.new(d1, d2)}}
  end

  ## Timeouted events
  def handle_info(:check_registry, %{:state => :wait_for_registrations} = state) do
    Process.cancel_timer(state.timer)
    {:noreply, check_registry(state)}
  end

  def handle_info(:check_joins, %{:state => :wait_for_joins} = state) do
    Process.cancel_timer(state.timer)
    {:noreply, check_joins(state)}
  end

  def handle_info(:send_your_turn, %{:state => :round} = state) do
    Process.cancel_timer(state.timer)
    {:noreply, send_your_turn(state)}
  end

  def handle_info(:check_action, %{:state => :round, :action => nil} = state) do
    {:noreply, player_lost_aftermath(state, "DID NOT TAKE TURN")}
  end

  def handle_info(:check_action, %{:state => :round, :action => :rolls} = state) do
    Process.cancel_timer(state.timer)
    {:noreply, handle_roll(state)}
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

  defp player_lost_aftermath(state, reason) do
    Process.cancel_timer(state.timer)
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER LOST;#{name};#{reason}")
    update_score(state.playerno, :lost)
    get_scoremsg() |> broadcast_message()
    %MiaServer.Game{:round => state.round+1, :timer => Process.send_after(self(), :check_registry, @timeout)}
  end

  defp player_won_aftermath(state, reason) do
    Process.cancel_timer(state.timer)
    players = for pn <- 0..MiaServer.Playerlist.get_participating_number()-1, pn != state.playerno do
      {_i, _p, name} = MiaServer.Playerlist.get_participating_player(pn)
      name
    end
    broadcast_message("PLAYER LOST;" <> Enum.join(players,",") <> ";#{reason}")
    update_score(state.playerno, :won)
    get_scoremsg() |> broadcast_message()
    %MiaServer.Game{:round => state.round+1, :timer => Process.send_after(self(), :check_registry, @timeout)}
  end

  defp handle_see(state) do
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER WANTS TO SEE;#{name}")
    cond do
      state.dice == nil ->
        player_lost_aftermath(state, "SEE BEFORE FIRST ROLL")
      MiaServer.Dice.higher?(state.announced, state.dice) ->
        player_lost_aftermath(%{state | :playerno => prev_playerno(state)}, "CAUGHT BLUFFING")
      true ->
        player_lost_aftermath(state, "SEE FAILED")
    end
  end

  defp handle_announce(state, d1, d2) do
    case MiaServer.Dice.new(d1, d2) do
      :invalid ->
        player_lost_aftermath(state, "INVALID TURN")
      announced_dice ->
        {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
        broadcast_message("ANNOUNCED;#{name};#{announced_dice}")
        cond do
          state.announced != nil and MiaServer.Dice.higher?(state.announced, announced_dice) ->
            player_lost_aftermath(state, "ANNOUNCED LOSING DICE")
          not MiaServer.Dice.mia?(state.dice) and MiaServer.Dice.mia?(announced_dice) ->
            player_lost_aftermath(state, "LIED ABOUT MIA")
          MiaServer.Dice.mia?(state.dice) and MiaServer.Dice.mia?(announced_dice) ->
            player_won_aftermath(state, "MIA")
          true ->
            %{state | :state => :round,
                      :playerno => next_playerno(state),
                      :announced => announced_dice,
                      :timer => Process.send_after(self(), :send_your_turn, @timeout)}
        end
    end
  end

  defp check_registry(state) do
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
    {nextstate, timer} = cond do
      length(registered_players) > 1 ->
        send_invitations(registered_participants)
        {:wait_for_joins, Process.send_after(self(), :check_joins, @timeout)}
      true ->
        {:wait_for_registrations, Process.send_after(self(), :check_registry, @timeout)}
    end
    %{state | :state => nextstate, :timer => timer}
  end

  defp check_joins(state) do
    joined_players = MiaServer.Playerlist.get_joined_players()
    {reply, state, next} = case length(joined_players) do
      0 -> {"ROUND CANCELED;NO PLAYERS", %{state | :state => :wait_for_registrations}, :check_registry}
      1 -> {"ROUND CANCELED;ONLY ONE PLAYER", %{state | :state => :wait_for_registrations}, :check_registry}
      _ -> playerlist = generate_playerlist(joined_players)
             |> store_playerlist()
             |> playerstring()
           {"ROUND STARTED;#{state.round};#{playerlist}", %{state | :state => :round, :playerno => 0}, :send_your_turn}
    end
    broadcast_message(reply)
    %{state | :timer => Process.send_after(self(), next, @timeout)}
  end

  defp handle_roll(state) do
    {ip, port, name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    broadcast_message("PLAYER ROLLS;#{name}")
    dice = case state.injected do
      nil -> MiaServer.DiceRoller.roll()
      injected -> injected
    end
    token = uuid()
    reply = "ROLLED;#{dice};#{token}"
    MiaServer.UDP.reply(ip, port, reply)
    %{state | :state => :wait_for_announce,
              :token => token,
              :action => nil,
              :dice => dice,
              :injected => nil,
              :timer => Process.send_after(self(), :check_announcement, @timeout)}
  end

  defp send_your_turn(state) do
    {ip, port, _name} = MiaServer.Playerlist.get_participating_player(state.playerno)
    token = uuid()
    MiaServer.UDP.reply(ip, port, "YOUR TURN;#{token}")
    %{state | :token => token,
              :action => nil,
              :timer => Process.send_after(self(), :check_action, @timeout)}
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

  defp next_playerno(state) do
    numplayers = MiaServer.Playerlist.get_participating_number()
    if state.playerno >= numplayers-1, do: 0, else: state.playerno+1
  end

  defp prev_playerno(state) do
    numplayers = MiaServer.Playerlist.get_participating_number()
    if state.playerno == 0, do: numplayers-1, else: state.playerno-1
  end

  defp playerstring(playerlist) do
    playerlist
      |> Enum.map(fn [_ip, _port, name, _score] -> name end)
      |> Enum.join(",")
  end

end
