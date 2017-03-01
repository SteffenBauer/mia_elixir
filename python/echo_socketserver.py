#!/usr/bin/env python

import SocketServer

class MyUDPHandler(SocketServer.BaseRequestHandler):
  def handle(self):
    data, socket = self.request
    print "Received", data.strip(), "from", self.client_address
    socket.sendto(data, self.client_address)

if __name__ == "__main__":
    HOST, PORT = '', 4080
    server = SocketServer.UDPServer((HOST, PORT), MyUDPHandler)
    server.serve_forever()
