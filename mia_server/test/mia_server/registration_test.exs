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

end
