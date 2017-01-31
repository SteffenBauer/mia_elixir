defmodule TrialServerTest do
  use ExUnit.Case
  doctest TrialServer

  setup do
    Application.stop(:trial_server)
    :ok = Application.start(:trial_server)
  end

  setup do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:trial_server, :port)
    {:ok, socket: socket, port: port}
  end



  test "the truth" do
    assert 1 + 1 == 2
  end
end
