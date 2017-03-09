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

  defp open_udp_socket(ip \\ {127,0,0,1}) do
    opts = [:binary, active: false, ip: ip]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:trial_server, :port)
    {socket, port}
  end




end
