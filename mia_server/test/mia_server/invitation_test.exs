defmodule MiaServer.InvitationTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    Application.start(:mia_server)
    on_exit fn ->
      Application.stop(:mia_server)
      Logger.flush()
    end
  end

  @timeout Application.get_env(:mia_server, :timeout) + 50

  defp open_udp_socket(ip) do
    opts = [:binary, active: false, ip: ip]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:mia_server, :port)
    {socket, port}
  end

  defp send_and_recv(socket, port, command) do
    :ok = :gen_udp.send(socket, '127.0.0.1', port, command)
    case :gen_udp.recv(socket, 0, @timeout) do
      {:ok, {_addr, _port, data}} -> data
      {:error, reason} -> {:error, reason}
    end
  end

  @token ~r/ROUND STARTING;([0-9a-fA-F]{32})\n/

  test "No invitation when not enough registered players" do
    {socket, port} = open_udp_socket({127,0,0,1})
    assert :gen_udp.recv(socket, 0, @timeout) == {:error, :timeout}
    send_and_recv(socket, port, "REGISTER;player1")
    assert :gen_udp.recv(socket, 0, @timeout) == {:error, :timeout}
  end

  test "Invitation once two players are registered" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    {socket3, port3} = open_udp_socket({127,0,0,3})
    send_and_recv(socket1, port1, "REGISTER;player1")
    send_and_recv(socket3, port3, "REGISTER_SPECTATOR")
    assert :gen_udp.recv(socket1, 0, @timeout) == {:error, :timeout}
    assert :gen_udp.recv(socket2, 0, @timeout) == {:error, :timeout}
    assert :gen_udp.recv(socket3, 0, @timeout) == {:error, :timeout}
    send_and_recv(socket2, port2, "REGISTER;player2")
    assert {:ok, {_ip, _port, invitation1}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, invitation2}} = :gen_udp.recv(socket2, 0, @timeout)
    assert {:ok, {_ip, _port, invitation3}} = :gen_udp.recv(socket3, 0, @timeout)
    assert invitation1 =~ @token
    assert invitation2 =~ @token
    assert invitation3 == "ROUND STARTING\n"
  end

  test "Game aborted on no participants" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    send_and_recv(socket1, port1, "REGISTER;player1")
    send_and_recv(socket2, port2, "REGISTER;player2")
    assert {:ok, {_ip, _port, _invitation1}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, _invitation2}} = :gen_udp.recv(socket2, 0, @timeout)
    assert {:ok, {_ip, _port, "ROUND CANCELED;NO PLAYERS\n"}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, "ROUND CANCELED;NO PLAYERS\n"}} = :gen_udp.recv(socket2, 0, @timeout)
  end

  test "Game aborted on only one participant" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    send_and_recv(socket1, port1, "REGISTER;player1")
    send_and_recv(socket2, port2, "REGISTER;player2")
    assert {:ok, {_ip, _port, invitation1}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, _invitation2}} = :gen_udp.recv(socket2, 0, @timeout)
    assert [^invitation1, mytoken1] = Regex.run(@token, invitation1)
    :gen_udp.send(socket1, 'localhost', port1, "JOIN;"<>mytoken1)
    assert {:ok, {_ip, _port, "ROUND CANCELED;ONLY ONE PLAYER\n"}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, "ROUND CANCELED;ONLY ONE PLAYER\n"}} = :gen_udp.recv(socket2, 0, @timeout)
  end

  test "Game starts with two participants" do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    send_and_recv(socket1, port1, "REGISTER;player1")
    send_and_recv(socket2, port2, "REGISTER;player2")
    assert {:ok, {_ip, _port, invitation1}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, invitation2}} = :gen_udp.recv(socket2, 0, @timeout)
    assert [^invitation1, mytoken1] = Regex.run(@token, invitation1)
    assert [^invitation2, mytoken2] = Regex.run(@token, invitation2)
    :gen_udp.send(socket1, 'localhost', port1, "JOIN;"<>mytoken1)
    :gen_udp.send(socket2, 'localhost', port2, "JOIN;"<>mytoken2)
    assert {:ok, {_ip, _port, "ROUND STARTED;1\n"}} = :gen_udp.recv(socket1, 0, @timeout)
    assert {:ok, {_ip, _port, "ROUND STARTED;1\n"}} = :gen_udp.recv(socket2, 0, @timeout)
  end

end
