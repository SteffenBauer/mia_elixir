defmodule MiaServer.Parser do

  def parse_packet(ip, port, data) do
    case data do
      "REGISTER;" <> name ->
        MiaServer.Registry.register_player(ip, port, name)
      "REGISTER_SPECTATOR" ->
        MiaServer.Registry.register_spectator(ip, port)
      "JOIN;" <> token ->
        MiaServer.Game.register_join(ip, port, token)
      "ANNOUNCE;" <> <<d1::binary-size(1)>> <> "," <> <<d2::binary-size(1)>> <> ";" <> token ->
        MiaServer.Game.do_announce(String.to_integer(d1), String.to_integer(d2), token)
      "ROLL;" <> token ->
        MiaServer.Game.do_roll(token)
      "SEE;" <> token ->
        MiaServer.Game.do_see(token)
      other ->
        MiaServer.Game.invalid(ip, port, other)
    end
  end

end
