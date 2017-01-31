defmodule EchoServerTest do
  use ExUnit.Case
  doctest EchoServer

  setup do
    Application.stop(:echo_server)
    :ok = Application.start(:echo_server)
  end

  setup do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:echo_server, :port)
    {:ok, socket: socket, port: port}
  end

  test "server interaction", %{socket: socket, port: port} do
    assert send_and_recv(socket, port, "UNKNOWN") == "UNKNOWN"
    assert send_and_recv(socket, port, "") == ""
  end

  defp send_and_recv(socket, port, command) do
    :ok = :gen_udp.send(socket, 'localhost', port, command)
    {:ok, {addr, port, data}} = :gen_udp.recv(socket, 0)
    data
  end
end
