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

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA game machine"
    Process.send_after(self(), :check_registry, @timeout)
    {:ok, {:waiting, 1}}
  end

  def handle_cast({:join, ip, port, token}, {:wait_for_joins, roundno}) do
    MiaServer.Playerlist.join_player(ip, port, token)
    {:noreply, {:wait_for_joins, roundno}}
  end
  def handle_cast({:join, _ip, _port, _token}, {state, roundno}) do
    {:noreply, {state, roundno}}
  end

  def handle_info(:check_registry, {:waiting, roundno}) do
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
    {:noreply, {state, roundno}}
  end

  def handle_info(:check_joins, {:wait_for_joins, roundno}) do
    joined_players = MiaServer.Playerlist.get_joined_players()
    {reply, fyt} = case length(joined_players) do
      0 -> {"ROUND CANCELED;NO PLAYERS", nil}
      1 -> {"ROUND CANCELED;ONLY ONE PLAYER", nil}
      _ -> playerlist = generate_playerlist(joined_players)
           [ip, port, _name] = playerlist |> hd
           playerlist = playerlist
             |> store_playerlist()
             |> playerstring()
           {"ROUND STARTED;#{roundno};#{playerlist}", {ip, port}}
    end
    MiaServer.Registry.get_registered()
      |> Enum.each(fn [ip, port, _role] -> MiaServer.UDP.reply(ip, port, reply) end)
    if fyt do
      {ip, port} = fyt
      MiaServer.UDP.reply(ip, port, "YOUR TURN;#{uuid()}")
    end
    Process.send_after(self(), :check_registry, @timeout)
    state = :waiting
    {:noreply, {state, roundno}}
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
