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
    {:ok, {_addr, _port, data}} = :gen_udp.recv(socket, 0, 1000)
    data
  end

  defp open_udp_socket(ip \\ {127,0,0,1}) do
    opts = [:binary, active: false, ip: ip]
    {:ok, socket} = :gen_udp.open(0, opts)
    port = Application.get_env(:trial_server, :port)
    {socket, port}
  end

  defp get_stored_trial(uuid) do
    stored_trial = TrialServer.Store.pop_trial(uuid)
    TrialServer.Store.put_trial(stored_trial)
    stored_trial
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
      stored_trial = get_stored_trial(uuid)
      send_and_recv(socket, port, "#{uuid}:#{stored_trial.solution}")
    end)
    assert final =~ "ALL CORRECT"
  end

  test "Fail all trials", %{socket: socket, port: port} do
    trial = send_and_recv(socket, port, "START")
    final = 1..5 |> Enum.reduce(trial, fn _, t ->
      [_, _type, uuid, _nums] = Regex.run(@trial, t)
      stored_trial = get_stored_trial(uuid)
      send_and_recv(socket, port, "#{uuid}:#{stored_trial.solution+1}")
    end)
    assert final =~ "5 WRONG 0 CORRECT"
  end

  test "Two clients", %{socket: socket, port: port} do
    {socket2, port2} = open_udp_socket({127,0,0,2})
    :ok = :gen_udp.send(socket, 'localhost', port, "START")
    :ok = :gen_udp.send(socket2, 'localhost', port2, "START")
    {:ok, {_addr, _port, trial1}} = :gen_udp.recv(socket, 0, 1000)
    {:ok, {_addr, _port, trial2}} = :gen_udp.recv(socket2, 0, 1000)
    {final1, final2} = 1..5 |> Enum.reduce({trial1, trial2}, fn _, {t1, t2} ->
      [_, _type, uuid1, _nums] = Regex.run(@trial, t1)
      [_, _type, uuid2, _nums] = Regex.run(@trial, t2)
      stored_trial1 = get_stored_trial(uuid1)
      stored_trial2 = get_stored_trial(uuid2)
      :ok = :gen_udp.send(socket, 'localhost', port, "#{uuid1}:#{stored_trial1.solution}")
      :ok = :gen_udp.send(socket2, 'localhost', port2, "#{uuid2}:#{stored_trial2.solution+1}")
      {:ok, {_addr, _port, t1}} = :gen_udp.recv(socket, 0, 1000)
      {:ok, {_addr, _port, t2}} = :gen_udp.recv(socket2, 0, 1000)
      {t1, t2}
    end)
    assert final1 =~ "ALL CORRECT"
    assert final2 =~ "5 WRONG 0 CORRECT"
    :gen_udp.close(socket2)
  end

end
