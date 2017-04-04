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
    parttab = :ets.new(:"#{__MODULE__}_notify", [:set, :private])
    Process.send_after(self(), :check_registry, @timeout)
    {:ok, {:waiting, parttab, 1}}
  end

  def handle_cast({:join, ip, port, token}, {:wait_for_joins, parttab, roundno}) do
    if :ets.match(parttab, {ip, port, token}) != [] do
      :ets.insert(parttab, {ip, port, :joined})
    end
    {:noreply, {:wait_for_joins, parttab, roundno}}
  end
  def handle_cast({:join, _ip, _port, _token}, {state, parttab, roundno}) do
    {:noreply, {state, parttab, roundno}}
  end

  def handle_info(:check_registry, {:waiting, parttab, roundno}) do
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
      |> length
    state = cond do
      registered_players > 1 ->
        send_invitations(registered_participants, parttab)
        Process.send_after(self(), :check_joins, @timeout)
        :wait_for_joins
      true ->
        Process.send_after(self(), :check_registry, @timeout)
        :waiting
    end
    {:noreply, {state, parttab, roundno}}
  end

  def handle_info(:check_joins, {:wait_for_joins, parttab, roundno}) do
    joined_players = :ets.match(parttab, {:"$1", :"$2", :joined})
    reply = case length(joined_players) do
      0 -> "ROUND CANCELED;NO PLAYERS"
      1 -> "ROUND CANCELED;ONLY ONE PLAYER"
      _ -> playerlist = generate_playerlist(joined_players)
           "ROUND STARTED;#{roundno};#{playerlist}"
    end
    MiaServer.Registry.get_registered()
      |> Enum.each(fn [ip, port, _role] -> MiaServer.UDP.reply(ip, port, reply) end)
    Process.send_after(self(), :check_registry, @timeout)
    state = :waiting
    {:noreply, {state, parttab, roundno}}
  end

## Private helper functions

  defp send_invitations(participants, parttab) do
    :ets.delete_all_objects(parttab)
    participants
      |> Enum.map(fn [ip, port, role] -> generate_invitation(ip, port, role, parttab) end)
      |> Enum.each(fn {ip, port, msg} -> MiaServer.UDP.reply(ip, port, msg) end)
  end

  defp generate_invitation(ip, port, :player, parttab) do
    token = uuid()
    :ets.insert(parttab, {ip, port, token})
    {ip, port, "ROUND STARTING;"<>token}
  end
  defp generate_invitation(ip, port, :spectator, _parttab) do
    {ip, port, "ROUND STARTING"}
  end

  defp uuid() do
    for _ <- 1..32 do :rand.uniform(16)-1 |> Integer.to_string(16) end
    |> Enum.join
  end

  defp generate_playerlist(players) do
    MiaServer.Registry.get_players()
      |> Enum.filter(fn [ip, port, _name] -> [ip, port] in players end)
      |> Enum.shuffle
      |> Enum.map(fn [_ip, _port, name] -> name end)
      |> Enum.join(",")
  end

end
