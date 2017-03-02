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

  def test_player_registration(self):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(1)
    s.sendto("REGISTER;test player", ('localhost', 4080))
    self.assertEqual(s.recv(1024), "REJECTED")
    s.sendto("REGISTER;testplayer", ('localhost', 4080))
    self.assertEqual(s.recv(1024), "REGISTERED")
    s.sendto("REGISTER;testplayer", ('localhost', 4080))
    self.assertEqual(s.recv(1024), "ALREADY REGISTERED")
    s2 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s2.settimeout(1)
    s2.sendto("REGISTER;testplayer", ('localhost', 4080))
    self.assertEqual(s2.recv(1024), "REJECTED")
    s2.close()
    s.close()

if __name__ == '__main__':
  unittest.main(verbosity=2)
