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
        {ip, port, String.trim(data)}
        |> TrialServer.Trial.handle_packet()
        |> reply(socket)
        serve(socket)
      {:EXIT, _pid, :shutdown} ->
        :gen_udp.close(socket)
      other ->
        Logger.error "UDP task received unexpected message '#{inspect other}'"
    end
  end

  defp reply(nil, _socket) do
    Logger.debug("No response")
  end
  defp reply({addr, port, response}, socket) do
    Logger.debug("Send '#{inspect response}' to #{inspect addr}:#{inspect port}")
    :gen_udp.send(socket, addr, port, response)
  end

end
