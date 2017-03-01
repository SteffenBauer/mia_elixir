defmodule EchoServerTest do
  use ExUnit.Case
  doctest EchoServer

  setup do
    Application.stop(:echo_server)
    :ok = Application.start(:echo_server)
  end

  test "server interaction" do #, %{socket: socket, port: port} do
    {socket, port} = open_udp_socket()
    assert send_and_recv(socket, port, "UNKNOWN") == "UNKNOWN"
    assert send_and_recv(socket, port, "") == ""
  end

  test "two clients access" do
    {socket1, port1} = open_udp_socket()
    {socket2, port2} = open_udp_socket()
    :ok = :gen_udp.send(socket1, 'localhost', port1, "FIRST_MESSAGE")
    :ok = :gen_udp.send(socket2, 'localhost', port2, "SECOND_MESSAGE")
    {:ok, {_addr, _port, reply1}} = :gen_udp.recv(socket1, 0)
    {:ok, {_addr, _port, reply2}} = :gen_udp.recv(socket2, 0)
    assert reply1 == "FIRST_MESSAGE"
    assert reply2 == "SECOND_MESSAGE"
    :gen_udp.close(socket1)
    :gen_udp.close(socket2)
  end

  defp send_and_recv(socket, port, command) do
    :ok = :gen_udp.send(socket, 'localhost', port, command)
    {:ok, {_addr, _port, data}} = :gen_udp.recv(socket, 0)
    data
  end

  defp open_udp_socket() do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:echo_server, :port)
    {socket, port}
  end
end
