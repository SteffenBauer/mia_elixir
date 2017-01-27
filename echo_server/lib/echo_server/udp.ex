defmodule EchoServer.UDP do

  require Logger

  def accept(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false])
    Logger.info "Listening on udp port #{port}"
    serve(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()
    |> write_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, {addr, port, data}} = :gen_udp.recv(socket, 0)
    {addr, port, data}
  end

  defp write_line({addr, port, line}, socket) do
    Logger.info("Sending '#{line |> String.trim}' to #{inspect addr}:#{port}")
    :gen_udp.send(socket, addr, port, line)
  end

end


