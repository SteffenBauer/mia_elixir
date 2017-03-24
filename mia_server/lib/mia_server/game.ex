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
    notifytable = :ets.new(:"#{__MODULE__}_notify", [:set, :private])
    Process.send_after(self(), :check_registry, @timeout)
    {:ok, {:waiting, notifytable}}
  end

  def handle_cast({:join, ip, port, token}, {state = :wait_for_joins, notifytable}) do
    {:noreply, {state, notifytable}}
  end
  def handle_cast({:join, _ip, _port, _token}, {state, notifytable}) do
    {:noreply, {state, notifytable}}
  end

  def handle_info(:check_registry, {state = :waiting, notifytable}) do
    registered_participants = MiaServer.Registry.get_registered()
    registered_players = registered_participants
      |> Enum.filter(fn [_, _, role] -> role == :player end)
      |> length
    state = cond do
      registered_players > 1 ->
        send_invitations(registered_participants, notifytable)
        Process.send_after(self(), :check_joins, @timeout)
        :wait_for_joins
      true ->
        Process.send_after(self(), :check_registry, @timeout)
        :waiting
    end
    {:noreply, {state, notifytable}}
  end

  def handle_info(:check_joins, {state = :wait_for_joins, notifytable}) do

    {:noreply, {state, notifytable}}
  end

## Private helper functions

  defp send_invitations(participants, notifytable) do
    :ets.delete_all_objects(notifytable)
    participants
      |> Enum.map(fn [ip, port, role] -> generate_invitation(ip, port, role, notifytable) end)
      |> Enum.each(fn {ip, port, msg} -> MiaServer.UDP.reply(ip, port, msg) end)
  end

  defp generate_invitation(ip, port, :player, notifytable) do
    token = uuid()
    :ets.insert(notifytable, {ip, port, token})
    {ip, port, "ROUND STARTING;"<>token}
  end
  defp generate_invitation(ip, port, :spectator, _notifytable) do
    {ip, port, "ROUND STARTING"}
  end

  defp uuid() do
    for _ <- 1..32 do :rand.uniform(16)-1 |> Integer.to_string(16) end
    |> Enum.join
  end

end
