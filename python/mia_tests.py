#!/usr/bin/env python

import unittest
import threading
import SocketServer
import socket
import mia_server

class TestMiaServer(unittest.TestCase):

  def setUp(self):
    print "\nStart MIA Server"
    self.server = SocketServer.UDPServer(('', 4080), mia_server.MiaHandler)
    server_thread = threading.Thread(target=self.server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

  def tearDown(self):
    print "Stop MIA Server"
    self.server.shutdown()
    self.server.server_close()

  def test_registration(self):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(1)
    s.sendto("REGISTER;testplayer", ('localhost', 4080))
    data = s.recv(1024)
    self.assertEqual(data, "REGISTERED")
    s.close()


if __name__ == '__main__':
  unittest.main(verbosity=2)
