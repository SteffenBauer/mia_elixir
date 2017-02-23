defmodule TrialServerTest do
  use ExUnit.Case, async: false
  require Logger
  doctest TrialServer

  setup do
    Application.start(:trial_server)
    on_exit fn ->
      Application.stop(:trial_server)
      Logger.flush()
    end
  end

  setup do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:trial_server, :port)
    on_exit fn -> :gen_udp.close(socket) end
    {:ok, socket: socket, port: port}
  end

  defp send_and_recv(socket, port, command) do
    :ok = :gen_udp.send(socket, 'localhost', port, command)
    {:ok, {_addr, _port, data}} = :gen_udp.recv(socket, 0)
    data
  end

  @trial ~r/(ADD|SUBTRACT|MULTIPLY):([0-9a-fA-F]{32})(:[0-9]+)+/

  test "Start new trial round", %{socket: socket, port: port} do
    assert send_and_recv(socket, port, "START") =~ @trial
  end

  test "Receive another trial test", %{socket: socket, port: port} do
    trial = send_and_recv(socket, port, "START")
    [_, _type, uuid, _nums] = Regex.run(@trial, trial)
    nexttrial = send_and_recv(socket, port, "#{uuid}:0")
    assert nexttrial =~ @trial
    [_, _type, nextuuid, _nums] = Regex.run(@trial, nexttrial)
    refute uuid == nextuuid
  end

  test "Solve all trials correctly", %{socket: socket, port: port} do
    trial = send_and_recv(socket, port, "START")
    final = 1..5 |> Enum.reduce(trial, fn _, t ->
      [_, _type, uuid, _nums] = Regex.run(@trial, t)
      stored_trial = TrialServer.Store.pop_trial(uuid) |> hd
      TrialServer.Store.put_trial(stored_trial)
      send_and_recv(socket, port, "#{uuid}:#{stored_trial.solution}")
    end)
    assert final =~ "ALL CORRECT"
  end

  test "Fail all trials", %{socket: socket, port: port} do
    trial = send_and_recv(socket, port, "START")
    final = 1..5 |> Enum.reduce(trial, fn _, t ->
      [_, _type, uuid, _nums] = Regex.run(@trial, t)
      stored_trial = TrialServer.Store.pop_trial(uuid) |> hd
      TrialServer.Store.put_trial(stored_trial)
      send_and_recv(socket, port, "#{uuid}:#{stored_trial.solution+1}")
    end)
    assert final =~ "5 WRONG 0 CORRECT"
  end

end
