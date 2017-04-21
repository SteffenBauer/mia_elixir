defmodule MiaServer.RegistrationTest do
  use ExUnit.Case, async: false
  alias MiaServer.Registry
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
    {:ok, localport} = :inet.port(socket)
    assert send_and_recv(socket, port, "REGISTER;player") == "REGISTERED\n"
    assert Registry.get_players() == [[{127,0,0,1}, localport, "player", 0]]
    assert Registry.get_registered() == [[{127,0,0,1}, localport, :player]]
  end

  test "Register as spectator" do
    {socket, port} = open_udp_socket({127,0,0,1})
    {:ok, localport} = :inet.port(socket)
    assert send_and_recv(socket, port, "REGISTER_SPECTATOR") == "REGISTERED\n"
    assert Registry.get_players() == []
    assert Registry.get_registered() == [[{127,0,0,1}, localport, :spectator]]
  end

  test "Reject wrong names" do
    {socket, port} = open_udp_socket({127,0,0,1})
    assert send_and_recv(socket, port, "REGISTER;012345678901234567890") == "REJECTED\n"
    assert send_and_recv(socket, port, "REGISTER;play er") == "REJECTED\n"
    assert send_and_recv(socket, port, "REGISTER;play;er") == "REJECTED\n"
    assert send_and_recv(socket, port, "REGISTER;play,er") == "REJECTED\n"
    assert Registry.get_registered() == []
  end

  test "Reject already registered name" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {:ok, localport1} = :inet.port(socket1)
    {socket2, port2} = open_udp_socket({127,0,0,2})
    assert send_and_recv(socket1, port1, "REGISTER;player") == "REGISTERED\n"
    assert send_and_recv(socket2, port2, "REGISTER;player") == "REJECTED\n"
    assert Registry.get_players() == [[{127,0,0,1}, localport1, "player", 0]]
    assert Registry.get_registered() == [[{127,0,0,1}, localport1, :player]]
  end

  test "Re-Register from same IP" do
    {socket, port} = open_udp_socket({127,0,0,1})
    {:ok, localport1} = :inet.port(socket)
    assert send_and_recv(socket, port, "REGISTER;player") == "REGISTERED\n"
    assert send_and_recv(socket, port, "REGISTER;player") == "ALREADY REGISTERED\n"
    assert Registry.get_players() == [[{127,0,0,1}, localport1, "player", 0]]
    assert Registry.get_registered() == [[{127,0,0,1}, localport1, :player]]
    :gen_udp.close(socket)
    {socket, port} = open_udp_socket({127,0,0,1})
    {:ok, localport2} = :inet.port(socket)
    assert localport1 != localport2
    assert send_and_recv(socket, port, "REGISTER;player") == "ALREADY REGISTERED\n"
    assert Registry.get_players() == [[{127,0,0,1}, localport2, "player", 0]]
    assert Registry.get_registered() == [[{127,0,0,1}, localport2, :player]]
  end

  test "Multiple registrations" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    {socket3, port3} = open_udp_socket({127,0,0,3})
    {socket4, port4} = open_udp_socket({127,0,0,4})
    {:ok, localport1} = :inet.port(socket1)
    {:ok, localport2} = :inet.port(socket2)
    {:ok, localport3} = :inet.port(socket3)
    {:ok, localport4} = :inet.port(socket4)
    assert send_and_recv(socket1, port1, "REGISTER;player1") == "REGISTERED\n"
    assert send_and_recv(socket2, port2, "REGISTER_SPECTATOR") == "REGISTERED\n"
    assert send_and_recv(socket3, port3, "REGISTER_SPECTATOR") == "REGISTERED\n"
    assert send_and_recv(socket3, port3, "REGISTER_SPECTATOR") == "ALREADY REGISTERED\n"
    assert send_and_recv(socket4, port4, "REGISTER;player1") == "REJECTED\n"
    assert send_and_recv(socket4, port4, "REGISTER;player2") == "REGISTERED\n"
    assert Registry.get_players()
      |> Enum.sort() == [[{127,0,0,1}, localport1, "player1", 0],
                         [{127,0,0,4}, localport4, "player2", 0]]
    assert Registry.get_registered()
      |> Enum.sort() == [[{127,0,0,1}, localport1, :player],
                         [{127,0,0,2}, localport2, :spectator],
                         [{127,0,0,3}, localport3, :spectator],
                         [{127,0,0,4}, localport4, :player]]
  end

end
