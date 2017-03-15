defmodule TrialServer.UDP do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def reply(message) do
    GenServer.cast(__MODULE__, message)
  end

## GenServer Callbacks

  def init(:ok) do
    Process.flag(:trap_exit, true)
    port = Application.get_env(:trial_server, :port)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    Logger.debug "Listening on udp port #{port}"
    {:ok, socket}
  end

  def handle_cast({addr, port, response}, socket) do
    Logger.debug("Send '#{inspect response}' to #{inspect addr}:#{inspect port}")
    :gen_udp.send(socket, addr, port, response <> "\n")
    {:noreply, socket}
  end

  def handle_info({:udp, _socket, ip, port, data}, socket) do
    Logger.debug("Received '#{inspect data}' from #{inspect ip}:#{inspect port}")
    Task.Supervisor.async_nolink(TrialServer.TaskSupervisor, TrialServer.Trial, :handle_packet, [{ip, port, String.trim(data)}])
    {:noreply, socket}
  end

  def handle_info({_ref, {ip, port, reply}}, socket) do
    reply({ip, port, reply})
    {:noreply, socket}
  end

  def handle_info({_ref, nil}, socket) do
    Logger.debug("No response")
    {:noreply, socket}
  end

  def handle_info(_other, socket) do
    {:noreply, socket}
  end

  def terminate(reason, socket) do
    Logger.debug("Shutting down UDP server for reason #{reason}, socket is #{inspect socket}")
    :gen_udp.close(socket)
  end

end
