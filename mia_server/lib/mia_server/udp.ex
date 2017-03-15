defmodule MiaServer.UDP do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

## API

  def reply(ip, port, message) do
    GenServer.cast(__MODULE__, {ip, port, message})
  end

  def reply(ip, port, nil) do
    Logger.debug("No response to #{inspect ip}:#{inspect port}")
  end

## GenServer Callbacks

  def init(:ok) do
    Process.flag(:trap_exit, true)
    port = Application.get_env(:mia_server, :port)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    Logger.info "Listening on udp port #{port}"
    {:ok, socket}
  end

  def handle_info({:udp, _socket, ip, port, data}, socket) do
    Logger.debug("Received '#{inspect data}' from #{inspect ip}:#{inspect port}")
    MiaServer.Parser.parse_packet(ip, port, String.trim(data))
    {:noreply, socket}
  end

  def handle_cast({ip, port, message}, socket) do
    Logger.debug("Send '#{inspect message}' to #{inspect ip}:#{inspect port}")
    :gen_udp.send(socket, ip, port, message <> "\n")
    {:noreply, socket}
  end

  def terminate(reason, socket) do
    Logger.debug("Shutting down MIA UDP server for reason #{reason}, socket is #{inspect socket}")
    :gen_udp.close(socket)
  end

end
