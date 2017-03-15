defmodule MiaServer.Parser do

  def parse_packet(ip, port, data) do
    case data do
      "REGISTER;" <> name -> MiaServer.Registry.register_player(ip, port, name)
      "REGISTER_SPECTATOR" -> MiaServer.Registry.register_spectator(ip, port)
      "JOIN;" <> token -> nil
      "ANNOUNCE;" <> <<dice::binary-size(3)>> <> ";" <> token -> nil
      "ROLL;" <> token -> nil
      "SEE;" <> token -> nil
      _ -> nil
    end
  end

end
