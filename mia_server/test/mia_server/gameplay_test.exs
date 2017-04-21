defmodule MiaServer.GameplayTest do
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

  defp setup_game() do
    token = ~r/ROUND STARTING;([0-9a-fA-F]{32})\n/
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    {socket3, port3} = open_udp_socket({127,0,0,3})
    send_and_recv(socket1, port1, "REGISTER;player1")
    send_and_recv(socket2, port2, "REGISTER;player2")
    send_and_recv(socket3, port3, "REGISTER_SPECTATOR")
    {:ok, {_ip, _port, invitation1}} = :gen_udp.recv(socket1, 0, @timeout)
    {:ok, {_ip, _port, invitation2}} = :gen_udp.recv(socket2, 0, @timeout)
    {:ok, {_ip, _port, "ROUND STARTING\n"}} = :gen_udp.recv(socket3, 0, @timeout)
    [^invitation1, mytoken1] = Regex.run(token, invitation1)
    [^invitation2, mytoken2] = Regex.run(token, invitation2)
    :gen_udp.send(socket1, 'localhost', port1, "JOIN;"<>mytoken1)
    :gen_udp.send(socket2, 'localhost', port2, "JOIN;"<>mytoken2)
    {:ok, {_ip, _port, _start1}} = :gen_udp.recv(socket1, 0, @timeout)
    {:ok, {_ip, _port, _start2}} = :gen_udp.recv(socket2, 0, @timeout)
    {:ok, {_i, _p, start}} = :gen_udp.recv(socket3, 0, @timeout)
    {start, {socket1, port1}, {socket2, port2}, {socket3, port3}}
  end

  defp extract_player_seq(startmsg, addr1, addr2) do
    [_, _turn, first, _second] = Regex.run(~r/ROUND STARTED;(.*);(.*),(.*)\n/, startmsg)
    case first do
      "player1" -> {{addr1, addr2}, first}
      "player2" -> {{addr2, addr1}, first}
    end
  end

  test "First player receives Your Turn" do
    {start, {s1, p1}, {s2, p2}, {_s3, _p3}} = setup_game()
    {{{socket, _port}, _}, _} = extract_player_seq(start, {s1, p1}, {s2, p2})
    assert {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    assert msg =~ ~r/YOUR TURN;([0-9a-fA-F]{32})\n/
  end

  test "First player rolls and receives dice" do
    {start, {s1, p1}, {s2, p2}, {s3, _p3}} = setup_game()
    {{{socket, port}, _}, player} = extract_player_seq(start, {s1, p1}, {s2, p2})
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    [_, token] = Regex.run(~r/YOUR TURN;([0-9a-fA-F]{32})\n/, msg)
    :gen_udp.send(socket, 'localhost', port, "ROLL;#{token}")
    {:ok, {_ip, _port, msg1}} = :gen_udp.recv(s1, 0, @timeout)
    {:ok, {_ip, _port, msg2}} = :gen_udp.recv(s2, 0, @timeout)
    {:ok, {_ip, _port, msg3}} = :gen_udp.recv(s3, 0, @timeout)
    assert msg1 == "PLAYER ROLLS;#{player}\n"
    assert msg2 == "PLAYER ROLLS;#{player}\n"
    assert msg3 == "PLAYER ROLLS;#{player}\n"
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    assert msg =~ ~r/ROLLED;[1-6],[1-6];[0-9a-fA-F]{32}/
  end

end
