defmodule TrialServer.UDP do

  require Logger

  def accept() do
    port = Application.get_env(:trial_server, :port)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    Logger.info "Listening on udp port #{port}"
    serve(socket)
  end

  defp serve(socket) do
    receive do
      {:udp, ^socket, ip, port, data} ->
        {ip, port, data |> String.trim()}
        |> TrialServer.Trial.handle_packet()
        |> reply(socket)
      other -> Logger.debug "UDP task received message '#{inspect other}'"
    end

    TrialServer.Store.print_store()
    serve(socket)
  end

  defp reply(nil, _socket) do
    Logger.debug("No response")
  end
  defp reply({addr, port, response}, socket) do
    :gen_udp.send(socket, addr, port, response)
  end

end
