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

  @token ~r/ROUND STARTING;[0-9a-fA-F]{32}\n/

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
    assert :gen_udp.recv(socket1, 0, @timeout) =~ @token
    assert :gen_udp.recv(socket2, 0, @timeout) =~ @token
    assert :gen_udp.recv(socket3, 0, @timeout) =~ "ROUND STARTING\n"
  end

end
