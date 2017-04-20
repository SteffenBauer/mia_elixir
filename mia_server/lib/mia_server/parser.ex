defmodule MiaServer.Parser do

  def parse_packet(ip, port, data) do
    case data do
      "REGISTER;" <> name ->
        MiaServer.Registry.register_player(ip, port, name)
      "REGISTER_SPECTATOR" ->
        MiaServer.Registry.register_spectator(ip, port)
      "JOIN;" <> token ->
        MiaServer.Game.register_join(ip, port, token)
      "ANNOUNCE;" <> <<_dice::binary-size(3)>> <> ";" <> _token ->
        nil
      "ROLL;" <> token ->
        MiaServer.Game.do_roll(token)
      "SEE;" <> _token ->
        nil
      _ ->
        nil
    end
  end

end
