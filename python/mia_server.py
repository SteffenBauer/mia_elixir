#!/usr/bin/env python

import SocketServer

HOST = ''
PORT = 4080

DEBUG = True

players = dict()

class MiaHandler(SocketServer.BaseRequestHandler):

  def handle(self):
    data, socket = self.request
    if DEBUG: print "Received", data.strip(), "from", self.client_address
    response = self._handle_packet(self.client_address, data.strip())
    if response:
      socket.sendto(response, self.client_address)
      if DEBUG: print "Send", response.strip(), "to", self.client_address
    elif DEBUG: print "No response"

  def _handle_packet(self, addr, data):
    if data.startswith("REGISTER;"):
      return self._register_player(data, addr)
    elif data.startswith("REGISTER_SPECTATOR"):
      return self._register_spectator(data, addr)

  def _register_player(self, data, addr):
    name = data.split(';',1)[1]
    if not self._valid_name(name): return "REJECTED"
    if players.has_key(name) and players[name]["ip"] == addr[0] and players[name]["port"] == addr[1]:
      return "ALREADY REGISTERED"
    if players.has_key(name): return "REJECTED"
    players[name] = {'mode': "PLAYER", 'ip': addr[0], 'port': addr[1], 'score': 0}
    return "REGISTERED"

  def _register_spectator(self, data, addr):
    pass

  def _valid_name(self, name):
    return len(name) <= 20 and name.isalnum()

if __name__ == "__main__":
    mia_server = SocketServer.UDPServer((HOST, PORT), MiaHandler)
    mia_server.serve_forever()
