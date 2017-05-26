defmodule MiaServer.GameplayTest do
  use ExUnit.Case, async: false
  require Logger

  @timeout round(Application.get_env(:mia_server, :timeout) * 1.25)

  setup do
    Application.start(:mia_server)
    on_exit fn ->
      Application.stop(:mia_server)
      Logger.flush()
    end
  end

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

  defp extract_player_seq(game, startmsg) do
    [_, turn, seq] = Regex.run(~r/ROUND STARTED;(.*);(.*)\n/, startmsg)

    players = seq
      |> String.split(",")
      |> Enum.with_index
      |> Enum.map(fn {"player" <> n,i} ->
                    {i+1, %{:name => "player"<>n,
                            :socket => Enum.at(game[:sockets], String.to_integer(n)-1),
                            :port => Enum.at(game[:ports], String.to_integer(n)-1)}
                    }
                  end)
      |> Enum.into(%{})

    %{game | :turn => String.to_integer(turn), :players => players}
  end

  defp setup_game() do
    {socket1, port1} = open_udp_socket({127,0,0,2})
    {socket2, port2} = open_udp_socket({127,0,0,3})
    {socket3, port3} = open_udp_socket({127,0,0,4})
    {socket4, port4} = open_udp_socket({127,0,0,5})
    {socket5, port5} = open_udp_socket({127,0,0,6})
    send_and_recv("REGISTER;player1", socket1, port1)
    send_and_recv("REGISTER;player2", socket2, port2)
    send_and_recv("REGISTER;player3", socket3, port3)
    send_and_recv("REGISTER_SPECTATOR", socket4, port4)
    send_and_recv("REGISTER_SPECTATOR", socket5, port5)
    token1 = receive_message(socket1) |> check_and_gettoken(:roundstarting)
    token2 = receive_message(socket2) |> check_and_gettoken(:roundstarting)
    _token3 = receive_message(socket3) |> check_and_gettoken(:roundstarting)
    "ROUND STARTING\n" = receive_message(socket4)
    "ROUND STARTING\n" = receive_message(socket5)
    send_to_server("JOIN;#{token1}", socket1, port1)
    send_to_server("JOIN;#{token2}", socket2, port2)
    receive_message(socket1)
    receive_message(socket2)
    receive_message(socket3)
    receive_message(socket4)
    start = receive_message(socket5)
    %{:turn => nil,
      :players => nil,
      :registered => ["player1", "player2", "player3"],
      :sockets => [socket1, socket2, socket3, socket4, socket5],
      :ports => [port1, port2, port3, port4, port5]}
    |> extract_player_seq(start)
  end

  defp check_broadcast_message(sockets, msg) do
    for s <- sockets do
      assert {:ok, {_ip, _port, ^msg}} = :gen_udp.recv(s, 0, @timeout)
    end
  end

  defp player_lost(game, playerno, reason) do
    check_broadcast_message(game[:sockets], "PLAYER LOST;#{game[:players][playerno][:name]};#{reason}\n")
    scoremsg = "SCORE;" <> (1..2
      |> Enum.to_list
      |> Enum.map(fn n -> "#{game[:players][n][:name]}:#{if(n == playerno, do: 0, else: 1)}" end)
      |> Enum.sort()
      |> Enum.join(",")) <> ",player3:0"

    check_broadcast_message(game[:sockets], scoremsg <> "\n")

    for n <- 1..5 do
      s = Enum.at(game[:sockets], n-1)
      {:ok, {_ip, _port, invitation}} = :gen_udp.recv(s, 0, @timeout)
      if n < 4 do
        assert invitation =~ ~r/ROUND STARTING;[0-9a-fA-F]{32}\n/
      else
        assert invitation == "ROUND STARTING\n"
      end
    end
  end

  defp make_roll_msg(token), do: "ROLL;#{token}"
  defp make_nonsense_msg(token), do: "BLABLA;#{token}"
  defp make_announcement_msg(token, d1, d2), do: "ANNOUNCE;#{d1},#{d2};#{token}"
  defp make_see_msg(token), do: "SEE;#{token}"

  defp want_to_see(game, playerno) do
    player = game[:players][playerno]
    player[:socket]
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_see_msg()
      |> send_to_server(player[:socket], player[:port])
    check_broadcast_message(game[:sockets], "PLAYER WANTS TO SEE;#{player[:name]}\n")
    game
  end

  defp roll(game, playerno) do
    player = game[:players][playerno]
    player[:socket]
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_roll_msg()
      |> send_to_server(player[:socket], player[:port])
    check_broadcast_message(game[:sockets], "PLAYER ROLLS;#{player[:name]}\n")
    game
  end

  defp announce(game, playerno, {d1, d2}) do
    player = game[:players][playerno]
    player[:socket]
      |> receive_message()
      |> check_and_gettoken(:rolled)
      |> make_announcement_msg(d1,d2)
      |> send_to_server(player[:socket], player[:port])
    check_broadcast_message(game[:sockets], "ANNOUNCED;#{player[:name]};#{d1},#{d2}\n")
    game
  end

  defp inject_dice(game, {d1, d2}) do
    MiaServer.Game.testing_inject_dice(d1,d2)
    game
  end

  defp check_yourturn(game, playerno) do
    game[:players][playerno][:socket]
      |> receive_message()
      |> check_and_gettoken(:yourturn)
    game
  end

  test "First player receives Your Turn" do
    game = setup_game()
    assert game[:turn] == 1
    game[:players][1][:socket] |> receive_message() |> check_and_gettoken(:yourturn)
  end

  test "First player rolls and receives dice" do
    game = setup_game()
    game |> roll(1)
    game[:players][1][:socket] |> receive_message() |> check_and_gettoken(:rolled)
  end

  test "First player does nothing" do
    game = setup_game()
    receive_message(game[:players][1][:socket])
    Process.sleep(@timeout)
    player_lost(game, 1, "DID NOT TAKE TURN")
  end

  test "Player sends invalid command" do
    game = setup_game()
    player = game[:players][1]
    player[:socket]
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_nonsense_msg()
      |> send_to_server(player[:socket], player[:port])
    player_lost(game, 1, "INVALID TURN")
  end

  test "Player rolls but fails to announce" do
    game = setup_game()
    game |> roll(1)
    receive_message(game[:players][1][:socket])
    Process.sleep(@timeout)
    player_lost(game, 1, "DID NOT ANNOUNCE")
  end

  test "Player announces without having rolled" do
    game = setup_game()
    player = game[:players][1]
    player[:socket]
      |> receive_message()
      |> check_and_gettoken(:yourturn)
      |> make_announcement_msg(2,1)
      |> send_to_server(player[:socket], player[:port])
    player_lost(game, 1, "INVALID TURN")
  end

  test "Game round with consecutive announcements" do
    setup_game()
      |> inject_dice({3,1})
      |> roll(1)
      |> announce(1, {3,1})
      |> inject_dice({3,2})
      |> roll(2)
      |> announce(2, {4,1})
      |> check_yourturn(1)
  end

  test "Player announces lower dice" do
    setup_game()
      |> inject_dice({6,1})
      |> roll(1)
      |> announce(1, {6,1})
      |> inject_dice({3,2})
      |> roll(2)
      |> announce(2, {5,1})
      |> player_lost(2, "ANNOUNCED LOSING DICE")
  end

  test "Player announces invalid MIA" do
    setup_game()
      |> inject_dice({6,1})
      |> roll(1)
      |> announce(1, {2,1})
      |> player_lost(1, "LIED ABOUT MIA")
  end

  test "Player announces valid MIA" do
    setup_game()
      |> inject_dice({2,1})
      |> roll(1)
      |> announce(1, {2,1})
      |> player_lost(2, "MIA")
  end

  test "Player wants to see, but no previous roll was made" do
    setup_game()
      |> want_to_see(1)
      |> player_lost(1, "SEE BEFORE FIRST ROLL")
  end

  test "Player wants to see, but roll was correctly annnounced" do
    setup_game()
      |> inject_dice({6,1})
      |> roll(1)
      |> announce(1, {5,1})
      |> want_to_see(2)
      |> player_lost(2, "SEE FAILED")
  end

  test "Player wants to see, and previous player bluffed" do
    setup_game()
      |> inject_dice({5,1})
      |> roll(1)
      |> announce(1, {6,1})
      |> want_to_see(2)
      |> player_lost(1, "CAUGHT BLUFFING")
  end

end
