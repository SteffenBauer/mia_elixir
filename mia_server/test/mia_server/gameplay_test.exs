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

  defp send_and_recv(command, socket, port) do
    :ok = :gen_udp.send(socket, '127.0.0.1', port, command)
    case :gen_udp.recv(socket, 0, @timeout) do
      {:ok, {_addr, _port, data}} -> data
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_to_server(msg, socket, port) do
    assert :ok = :gen_udp.send(socket, 'localhost', port, msg)
  end

  defp receive_message(socket) do
    assert {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, @timeout)
    msg
  end

  defp check_and_gettoken(message, type) do
    regex = case type do
      :roundstarting -> ~r/ROUND STARTING;([0-9a-fA-F]{32})\n/
      :yourturn      -> ~r/YOUR TURN;([0-9a-fA-F]{32})\n/
      :rolled        -> ~r/ROLLED;[1-6],[1-6];([0-9a-fA-F]{32})\n/
    end
    assert message =~ regex
    [_, token] = Regex.run(regex, message)
    token
  end

  defp setup_game() do
    {socket1, port1} = open_udp_socket({127,0,0,1})
    {socket2, port2} = open_udp_socket({127,0,0,2})
    {socket3, port3} = open_udp_socket({127,0,0,3})
    send_and_recv("REGISTER;player1", socket1, port1)
    send_and_recv("REGISTER;player2", socket2, port2)
    send_and_recv("REGISTER_SPECTATOR", socket3, port3)
    token1 = receive_message(socket1) |> check_and_gettoken(:roundstarting)
    token2 = receive_message(socket2) |> check_and_gettoken(:roundstarting)
    "ROUND STARTING\n" = receive_message(socket3)
    send_to_server("JOIN;#{token1}", socket1, port1)
    send_to_server("JOIN;#{token2}", socket2, port2)
    receive_message(socket1)
    receive_message(socket2)
    start = receive_message(socket3)
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

  defp make_roll_msg(token), do: "ROLL;#{token}"
  defp make_nonsense_msg(token), do: "BLABLA;#{token}"
  defp make_announcement_msg(token, d1, d2), do: "ANNOUNCE;#{d1},#{d2};#{token}"

  test "First player receives Your Turn" do
    {startmsg, sockets, ports} = setup_game()
    {turn, _players, [socket | _], _ports} = extract_player_seq(startmsg, sockets, ports)
    assert turn == 1
    socket
      |> receive_message()
      |> check_and_gettoken(:yourturn)
  end

  test "First player rolls and receives dice" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], [port | _]} = extract_player_seq(startmsg, sockets, ports)
    socket
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(socket, port)
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player}\n")
    socket
      |> receive_message()
      |> check_and_gettoken(:rolled)
  end

  test "First player does nothing" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], _} = extract_player_seq(startmsg, sockets, ports)
    receive_message(socket)
    Process.sleep(@timeout)
    check_player_lost_aftermath(player, sockets, "DID NOT TAKE TURN")
  end

  test "Player sends invalid command" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], [port | _]} = extract_player_seq(startmsg, sockets, ports)
    socket
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_nonsense_msg()
      |> send_to_server(socket, port)
    check_player_lost_aftermath(player, sockets, "INVALID TURN")
  end

  test "Player rolls but fails to announce" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player | _], [socket | _], [port | _]} = extract_player_seq(startmsg, sockets, ports)
    socket
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(socket, port)
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player}\n")
    receive_message(socket)
    Process.sleep(@timeout)
    check_player_lost_aftermath(player, sockets, "DID NOT ANNOUNCE")
  end

  test "Game round with consecutive announcements" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player1, player2 | _], [socket1, socket2 | _], [port1, port2 | _]} = extract_player_seq(startmsg, sockets, ports)
    MiaServer.Game.testing_inject_dice(3,1)
    socket1
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(socket1, port1)
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player1}\n")
    socket1
      |> receive_message()
      |> check_and_gettoken(:rolled)
      |> make_announcement_msg(3,1)
      |> send_to_server(socket1, port1)
    check_broadcast_message(sockets, "ANNOUNCED;#{player1};3,1\n")
    # Second players turn
    MiaServer.Game.testing_inject_dice(3,2)
    socket2
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(socket2, port2)
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player2}\n")
    socket2
      |> receive_message()
      |> check_and_gettoken(:rolled)
      |> make_announcement_msg(4,1)
      |> send_to_server(socket2, port2)
    check_broadcast_message(sockets, "ANNOUNCED;#{player2};4,1\n")
    # Again first players turn
    socket1
      |> receive_message()
      |> check_and_gettoken(:yourturn)
  end

  test "Player announces lower dice" do
    {startmsg, sockets, ports} = setup_game()
    {1, [player1, player2 | _], [socket1, socket2 | _], [port1, port2 | _]} = extract_player_seq(startmsg, sockets, ports)
    MiaServer.Game.testing_inject_dice(6,1)
    socket1
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(socket1, port1)
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player1}\n")
    socket1
      |> receive_message()
      |> check_and_gettoken(:rolled)
      |> make_announcement_msg(6,1)
      |> send_to_server(socket1, port1)
    check_broadcast_message(sockets, "ANNOUNCED;#{player1};6,1\n")
    # Second players turn
    MiaServer.Game.testing_inject_dice(3,2)
    socket2
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(socket2, port2)
    check_broadcast_message(sockets, "PLAYER ROLLS;#{player2}\n")
    socket2
      |> receive_message()
      |> check_and_gettoken(:rolled)
      |> make_announcement_msg(5,1)
      |> send_to_server(socket2, port2)
    check_broadcast_message(sockets, "ANNOUNCED;#{player2};5,1\n")
    check_player_lost_aftermath(player2, sockets, "ANNOUNCED LOSING DICE")
  end

end
