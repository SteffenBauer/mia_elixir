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

  @timeout round(Application.get_env(:mia_server, :timeout) * 1.25)

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
    {start, [socket1, socket2, socket3], [port1, port2, port3]}
  end

  defp extract_player_seq(startmsg, sockets, ports) do
    [_, turn, seq] = Regex.run(~r/ROUND STARTED;(.*);(.*)\n/, startmsg)
    playerseq = seq |> String.split(",")
    socketseq = playerseq |> Enum.map(fn "player" <> n -> Enum.at(sockets, String.to_integer(n)-1) end)
    portseq = playerseq |> Enum.map(fn "player" <> n -> Enum.at(ports, String.to_integer(n)-1) end)
    {String.to_integer(turn), playerseq, socketseq, portseq}
  end

  defp check_broadcast_message(sockets, msg) do
    for s <- sockets do
      assert {:ok, {_ip, _port, m}} = :gen_udp.recv(s, 0, @timeout)
      assert msg == m
    end
  end

  defp check_player_lost_aftermath(player, sockets, reason) do
    check_broadcast_message(sockets, "PLAYER LOST;#{player};#{reason}\n")
    scoremsg = case player do
      "player1" -> "SCORE;player1:0,player2:1\n"
      "player2" -> "SCORE;player1:1,player2:0\n"
    end
    check_broadcast_message(sockets, scoremsg)
    invites = for s <- sockets do
      {:ok, {_ip, _port, invitation}} = :gen_udp.recv(s, 0, @timeout)
      invitation
    end
    [i | invites ] = invites; assert i =~ ~r/ROUND STARTING;[0-9a-fA-F]{32}\n/
    [i | invites ] = invites; assert i =~ ~r/ROUND STARTING;[0-9a-fA-F]{32}\n/
    assert invites == ["ROUND STARTING\n"]
  end

  test "First player receives Your Turn" do
    {startmsg, sockets, ports} = setup_game()
    {turn, _players, [socket | _], _ports} = extract_player_seq(startmsg, sockets, ports)
    assert turn == 1
    assert {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    assert msg =~ ~r/YOUR TURN;([0-9a-fA-F]{32})\n/
  end

  test "First player rolls and receives dice" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], [port | _]} = extract_player_seq(startmsg, sockets, ports)
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    [_, token] = Regex.run(~r/YOUR TURN;([0-9a-fA-F]{32})\n/, msg)
    :gen_udp.send(socket, 'localhost', port, "ROLL;#{token}")
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player}\n")
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    assert msg =~ ~r/ROLLED;[1-6],[1-6];[0-9a-fA-F]{32}/
  end

  test "First player does nothing" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], _} = extract_player_seq(startmsg, sockets, ports)
    :gen_udp.recv(socket, 0, @timeout)
    Process.sleep(@timeout)
    check_player_lost_aftermath(player, sockets, "DID NOT TAKE TURN")
  end

  test "Player sends invalid command" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], [port | _]} = extract_player_seq(startmsg, sockets, ports)
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    [_, token] = Regex.run(~r/YOUR TURN;([0-9a-fA-F]{32})\n/, msg)
    :gen_udp.send(socket, 'localhost', port, "BLABLA;#{token}")
    check_player_lost_aftermath(player, sockets, "INVALID TURN")
  end

  test "Player rolls but fails to announce" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], [port | _]} = extract_player_seq(startmsg, sockets, ports)
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    [_, token] = Regex.run(~r/YOUR TURN;([0-9a-fA-F]{32})\n/, msg)
    :gen_udp.send(socket, 'localhost', port, "ROLL;#{token}")
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player}\n")
    :gen_udp.recv(socket, 0, @timeout) # ROLLED;<dice>
    Process.sleep(@timeout)
    check_player_lost_aftermath(player, sockets, "DID NOT ANNOUNCE")
  end

  test "First player rolls and announces" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player1, player2 | _], [socket1, socket2 | _], [port1, port2 | _]} = extract_player_seq(startmsg, sockets, ports)
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket1, 0, @timeout)
    [_, token] = Regex.run(~r/YOUR TURN;([0-9a-fA-F]{32})\n/, msg)
    :gen_udp.send(socket1, 'localhost', port1, "ROLL;#{token}")
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player1}\n")
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket1, 0, @timeout)
    [_, token] = Regex.run(~r/ROLLED;[1-6],[1-6];([0-9a-fA-F]{32})/, msg)
    MiaServer.Game.testing_inject_dice(MiaServer.Dice.new(3,1))
    :gen_udp.send(socket1, 'localhost', port1, "ANNOUNCE;3,1;#{token}")
    check_broadcast_message(sockets, "ANNOUNCED;#{player1};3,1\n")
    # Second players turn
    assert {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket2, 0, @timeout)
    assert msg =~ ~r/YOUR TURN;([0-9a-fA-F]{32})\n/
    [_, token] = Regex.run(~r/YOUR TURN;([0-9a-fA-F]{32})\n/, msg)
    :gen_udp.send(socket2, 'localhost', port2, "ROLL;#{token}")
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player2}\n")
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket2, 0, @timeout)
    [_, token] = Regex.run(~r/ROLLED;[1-6],[1-6];([0-9a-fA-F]{32})/, msg)
    MiaServer.Game.testing_inject_dice(MiaServer.Dice.new(3,2))
    :gen_udp.send(socket2, 'localhost', port2, "ANNOUNCE;4,1;#{token}")
    check_broadcast_message(sockets, "ANNOUNCED;#{player2};4,1\n")
    # Again first players turn
    assert {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket1, 0, @timeout)
    assert msg =~ ~r/YOUR TURN;([0-9a-fA-F]{32})\n/

  end

end
