defmodule TrialServer.UDP do

  require Logger

  def accept() do
    Process.flag(:trap_exit, true)
    port = Application.get_env(:trial_server, :port)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    Logger.info "Listening on udp port #{port}"
    serve(socket)
  end

  defp serve(socket) do
    receive do
      {:udp, ^socket, ip, port, data} ->
        Logger.debug("Received '#{inspect data}' from #{inspect ip}:#{inspect port}")
        Task.async(fn -> TrialServer.Trial.handle_packet({ip, port, String.trim(data)}) end)
      {:EXIT, _pid, :shutdown} ->
        :gen_udp.close(socket)
        exit(:normal)
      {_ref, {ip, port, reply}} ->
        reply({ip, port, reply}, socket)
      {_ref, nil} ->
        Logger.debug("No response")
      other ->
        Logger.info "UDP task received unexpected message '#{inspect other}'"
    end
    serve(socket)
  end

  defp reply({addr, port, response}, socket) do
    Logger.debug("Send '#{inspect response}' to #{inspect addr}:#{inspect port}")
    :gen_udp.send(socket, addr, port, response)
  end

end
