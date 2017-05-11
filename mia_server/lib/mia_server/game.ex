defmodule MiaServer.Game do
  @behaviour :gen_statem
  require Logger

  defstruct round: 1,
            playerno: 0,
            playerip: nil,
            token: nil,
            action: nil,
            dice: nil,
            announced: nil,
            injected: nil

  @timeout Application.get_env(:mia_server, :timeout)

  def start_link(), do: :gen_statem.start_link({:local, __MODULE__}, __MODULE__, [], [])
  def stop(), do: :gen_statem.stop(__MODULE__)

## API

  def register_join(ip, port, token) do
    :gen_statem.cast(__MODULE__, {:join, ip, port, token})
  end

  def do_roll(token) do
    :gen_statem.cast(__MODULE__, {:player_rolls, token})
  end

  def do_announce(d1, d2, token) do
    :gen_statem.cast(__MODULE__, {:player_announces, d1, d2, token})
  end

  def do_see(token) do
    :gen_statem.cast(__MODULE__, {:player_sees, token})
  end

  def invalid(ip, port, msg) do
    :gen_statem.cast(__MODULE__, {:invalid, ip, port, msg})
  end

  def testing_inject_dice(d1, d2) do
    :gen_statem.cast(__MODULE__, {:inject, d1, d2})
  end

## gen_statem Callbacks

  def init([]) do
    Logger.info "Starting MIA game machine"
    {:ok, :wait_for_registrations, %MiaServer.Game{}, {:state_timeout, @timeout, :check_registry}}
  end
  def terminate(_reason, _state, _sata), do: nil
  def code_change(_vsn, state, data, _extra), do: {:ok, state, data}
  def callback_mode(), do: :handle_event_function

  def handle_event(type, event, state, data) do
    currenttoken = data.token
    currentaction = data.action
    currentip = data.playerip
    case {type, event, state} do
      {:cast, {:join, ip, port, token}, :wait_for_joins} ->
        MiaServer.Playerlist.join_player(ip, port, token)
        :keep_state_and_data
      {:cast, {:player_sees, ^currenttoken}, :round} ->
        {:next_state, :wait_for_registrations, handle_see(data), {:state_timeout, @timeout, :check_registry}}
      {:cast, {:player_rolls, ^currenttoken}, :round} ->
        {:keep_state, %{data | :action => :rolls}}
      {:cast, {:player_announces, d1, d2, ^currenttoken}, :wait_for_announce} ->
        {state, data, timeout} = handle_announce(data, d1, d2)
        {:next_state, state, data, {:state_timeout, @timeout, timeout}}
      {:cast, {:player_announces, _, _, ^currenttoken}, _state} ->
        {:next_state, :wait_for_registrations, player_lost(data, "INVALID TURN"), {:state_timeout, @timeout, :check_registry}}
      {:cast, {:invalid, ^currentip, _port, _msg}, :round} ->
        {:next_state, :wait_for_registrations, player_lost(data, "INVALID TURN"), {:state_timeout, @timeout, :check_registry}}
      {:cast, {:inject, d1, d2}, :round} ->
        Logger.debug("Inject: Next die roll will be #{d1},#{d2}")
        {:keep_state, %{data | :injected => MiaServer.Dice.new(d1, d2)}}

      {:state_timeout, :check_registry, :wait_for_registrations} ->
        {state, timeout} = check_registry()
        {:next_state, state, data, {:state_timeout, @timeout, timeout}}
      {:state_timeout, :check_joins, :wait_for_joins} ->
        {state, timeout} = check_joins(data)
        {:next_state, state, data, {:state_timeout, @timeout, timeout}}
      {:state_timeout, :send_your_turn, :round} ->
        data = send_your_turn(data)
        {:next_state, :round, data, {:state_timeout, @timeout, :check_action}}
      {:state_timeout, :check_action, :round} when currentaction == :rolls ->
        data = handle_roll(data)
        {:next_state, :wait_for_announce, data, {:state_timeout, @timeout, :check_for_announcement}}
      {:state_timeout, :check_action, :round} when currentaction == nil ->
        data = player_lost(data, "DID NOT TAKE TURN")
        {:next_state, :wait_for_registrations, data, {:state_timeout, @timeout, :check_registry}}
      {:state_timeout, :check_for_announcement, :wait_for_announce} when currentaction == nil ->
        data = player_lost(data, "DID NOT ANNOUNCE")
        {:next_state, :wait_for_registrations, data, {:state_timeout, @timeout, :check_registry}}

      other -> Logger.warn "MiaGame got #{inspect other}, ignoring"; :keep_state_and_data
    end
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

  defp player_lost(data, reason) do
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(data.playerno)
    broadcast_message("PLAYER LOST;#{name};#{reason}")
    update_score(data.playerno, :lost)
    get_scoremsg() |> broadcast_message()
    %MiaServer.Game{:round => data.round+1}
  end

  defp player_won(data, reason) do
    players = for pn <- 0..MiaServer.Playerlist.get_participating_number()-1, pn != data.playerno do
      {_i, _p, name} = MiaServer.Playerlist.get_participating_player(pn)
      name
    end
    broadcast_message("PLAYER LOST;" <> Enum.join(players,",") <> ";#{reason}")
    update_score(data.playerno, :won)
    get_scoremsg() |> broadcast_message()
    %MiaServer.Game{:round => data.round+1}
  end

  defp handle_see(data) do
    {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(data.playerno)
    broadcast_message("PLAYER WANTS TO SEE;#{name}")
    cond do
      data.dice == nil ->
        player_lost(data, "SEE BEFORE FIRST ROLL")
      MiaServer.Dice.higher?(data.announced, data.dice) ->
        player_lost(%{data | :playerno => prev_playerno(data)}, "CAUGHT BLUFFING")
      true ->
        player_lost(data, "SEE FAILED")
    end
  end

  defp handle_announce(data, d1, d2) do
    case MiaServer.Dice.new(d1, d2) do
      :invalid ->
        {:wait_for_registrations, player_lost(data, "INVALID TURN"), :check_registry}
      announced_dice ->
        {_ip, _port, name} = MiaServer.Playerlist.get_participating_player(data.playerno)
        broadcast_message("ANNOUNCED;#{name};#{announced_dice}")
        cond do
          data.announced != nil and MiaServer.Dice.higher?(data.announced, announced_dice) ->
            {:wait_for_registrations, player_lost(data, "ANNOUNCED LOSING DICE"), :check_registry}
          not MiaServer.Dice.mia?(data.dice) and MiaServer.Dice.mia?(announced_dice) ->
            {:wait_for_registrations, player_lost(data, "LIED ABOUT MIA"), :check_registry}
          MiaServer.Dice.mia?(data.dice) and MiaServer.Dice.mia?(announced_dice) ->
            {:wait_for_registrations, player_won(data, "MIA"), :check_registry}
          true ->
            {:round, %{data | :playerno => next_playerno(data), :announced => announced_dice}, :send_your_turn}
        end
    end
  end

  defp check_registry() do
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
    cond do
      length(registered_players) > 1 ->
        send_invitations(registered_participants)
        {:wait_for_joins, :check_joins}
      true ->
        {:wait_for_registrations, :check_registry}
    end
  end

  defp check_joins(data) do
    joined_players = MiaServer.Playerlist.get_joined_players()
    {reply, nextstate, nexttimeout} = case length(joined_players) do
      0 -> {"ROUND CANCELED;NO PLAYERS", :wait_for_registrations, :check_registry}
      1 -> {"ROUND CANCELED;ONLY ONE PLAYER", :wait_for_registrations, :check_registry}
      _ -> playerlist = generate_playerlist(joined_players)
             |> store_playerlist()
             |> playerstring()
           {"ROUND STARTED;#{data.round};#{playerlist}", :round, :send_your_turn}
    end
    broadcast_message(reply)
    {nextstate, nexttimeout}
  end

  defp handle_roll(data) do
    {ip, port, name} = MiaServer.Playerlist.get_participating_player(data.playerno)
    broadcast_message("PLAYER ROLLS;#{name}")
    dice = case data.injected do
      nil -> MiaServer.DiceRoller.roll()
      injected -> injected
    end
    token = uuid()
    MiaServer.UDP.reply(ip, port, "ROLLED;#{dice};#{token}")
    %{data | :token => token, :action => nil, :dice => dice, :injected => nil}
  end

  defp send_your_turn(data) do
    {ip, port, _name} = MiaServer.Playerlist.get_participating_player(data.playerno)
    token = uuid()
    MiaServer.UDP.reply(ip, port, "YOUR TURN;#{token}")
    %{data | :token => token, :action => nil, :playerip => ip}
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
