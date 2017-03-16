defmodule MiaServer.ServerRegistrationTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    Application.start(:mia_server)
    on_exit fn ->
      Application.stop(:mia_server)
      Logger.flush()
    end
  end

  @timeout 300

  defp open_udp_socket(ip) do
    opts = [:binary, active: false, ip: ip]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:mia_server, :port)
    {socket, port}
  end

  defp send_and_recv(socket, port, command) do
    :ok = :gen_udp.send(socket, 'localhost', port, command)
    case :gen_udp.recv(socket, 0, @timeout) do
      {:ok, {_addr, _port, data}} -> data
      {:error, reason} -> {:error, reason}
    end
  end

  test "Register as player" do
    {socket, port} = open_udp_socket({127,0,0,1})
    assert send_and_recv(socket, port, "REGISTER;player") == "REGISTERED\n"
  end

  test "Register as spectator" do
    {socket, port} = open_udp_socket({127,0,0,1})
    assert send_and_recv(socket, port, "REGISTER_SPECTATOR") == "REGISTERED\n"
  end

  test "Reject wrong names" do
    {socket, port} = open_udp_socket({127,0,0,1})
    assert send_and_recv(socket, port, "REGISTER;012345678901234567890") == "REJECTED\n"
    assert send_and_recv(socket, port, "REGISTER;play er") == "REJECTED\n"
    assert send_and_recv(socket, port, "REGISTER;play;er") == "REJECTED\n"
    assert send_and_recv(socket, port, "REGISTER;play,er") == "REJECTED\n"
  end

  test "Reject already registered name" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    assert send_and_recv(socket1, port1, "REGISTER;player") == "REGISTERED\n"
    assert send_and_recv(socket2, port2, "REGISTER;player") == "REJECTED\n"
  end

  test "Re-Register from same IP" do
    {socket, port} = open_udp_socket({127,0,0,1})
    {:ok, localport1} = :inet.port(socket)
    assert send_and_recv(socket, port, "REGISTER;player") == "REGISTERED\n"
    assert send_and_recv(socket, port, "REGISTER;player") == "ALREADY REGISTERED\n"
    :gen_udp.close(socket)
    {socket, port} = open_udp_socket({127,0,0,1})
    {:ok, localport2} = :inet.port(socket)
    assert localport1 != localport2
    assert send_and_recv(socket, port, "REGISTER;player") == "ALREADY REGISTERED\n"
  end

end
