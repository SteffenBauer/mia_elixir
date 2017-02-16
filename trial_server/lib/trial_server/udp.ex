defmodule TrialServer.UDP do

  require Logger

  def accept() do
    port = Application.get_env(:trial_server, :port)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false])
    Logger.info "Listening on udp port #{port}"
    serve(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()
    |> TrialServer.Trial.handle_packet()
    |> reply(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, {addr, port, data}} = :gen_udp.recv(socket, 0)
    {addr, port, data |> String.trim()}
  end

  defp reply(nil, _socket) do
    Logger.debug("No response")
  end
  defp reply({addr, port, response}, socket) do
    :gen_udp.send(socket, addr, port, response)
  end

end
