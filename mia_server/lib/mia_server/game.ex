defmodule MiaServer.Game do
  use GenServer
  require Logger

  @timeout Application.get_env(:mia_server, :timeout)

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

## API

## GenServer Callbacks

  def init(:ok) do
    Logger.info "Starting MIA game machine"
    players = :ets.new(:"#{__MODULE__}_players", [:set, :private])
    notify = :ets.new(:"#{__MODULE__}_notify", [:set, :private])
    Process.send_after(self(), :check_registry, @timeout)
    {:ok, {:waiting, nil, players, notify}}
  end

  def handle_info(:check_registry, {state = :waiting, dice, playertable, notifytable}) do
    registered_players = MiaServer.Registry.get_players()
    registered_observers = MiaServer.Registry.get_registered()
    if length(registered_players) > 1 do
      create_invitations(registered_players, registered_observers)
        |> Enum.each(&MiaServer.UDP.reply/3)
      state = :wait_for_joins
    end
    Process.send_after(self(), :check_joins, @timeout)
    {:noreply, {state, dice, playertable, notifytable}}
  end

## Private helper functions

  defp create_invitations(players, observers) do

  end

end
