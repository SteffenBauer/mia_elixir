#!/usr/bin/env python

import SocketServer

HOST = ''
PORT = 4080

DEBUG = True

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
      response = self._register_player(data, addr)
    elif data.startswith("REGISTER_SPECTATOR"):
      response = self._register_spectator(data, addr)

  def _register_player(self, data, addr):
    pass

  def _register_spectator(self, data, addr):
    pass

if __name__ == "__main__":
    mia_server = SocketServer.UDPServer((HOST, PORT), MiaHandler)
    mia_server.serve_forever()
