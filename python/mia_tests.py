#!/usr/bin/env python

import unittest
import threading
import SocketServer
import socket
import mia_server

class TestRegistration(unittest.TestCase):

  def setUp(self):
    print "\nStart MIA Server"
    self.server = SocketServer.UDPServer(('', 4080), mia_server.MiaHandler)
    server_thread = threading.Thread(target=self.server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    print "Open test sockets"
    self.s1 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.s1.settimeout(1)
    self.s2 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.s2.bind(('127.0.0.2', 0))
    self.s2.settimeout(1)

  def tearDown(self):
    print "Close test sockets"
    self.s1.close()
    self.s2.close()
    print "Stop MIA Server"
    self.server.shutdown()
    self.server.server_close()

  def test_player_registration(self):
    self.s1.sendto("REGISTER;test player", ('localhost', 4080))
    self.assertEqual(self.s1.recv(1024), "REJECTED")
    self.s1.sendto("REGISTER;012345678901234567890", ('localhost', 4080))
    self.assertEqual(self.s1.recv(1024), "REJECTED")
    self.s1.sendto("REGISTER;testplayer", ('localhost', 4080))
    self.assertEqual(self.s1.recv(1024), "REGISTERED")
    self.s1.sendto("REGISTER;testplayer", ('localhost', 4080))
    self.assertEqual(self.s1.recv(1024), "ALREADY REGISTERED")
    self.s2.sendto("REGISTER;testplayer", ('localhost', 4080))
    self.assertEqual(self.s2.recv(1024), "REJECTED")
    self.s2.sendto("REGISTER;testplayer2", ('localhost', 4080))
    self.assertEqual(self.s2.recv(1024), "REGISTERED")

  def test_spectator_registration(self):
    self.s1.sendto("REGISTER_SPECTATOR", ('localhost', 4080))
    self.assertEqual(self.s1.recv(1024), "REGISTERED")
    self.s1.sendto("REGISTER_SPECTATOR", ('localhost', 4080))
    self.assertEqual(self.s1.recv(1024), "ALREADY REGISTERED")

class TestInvitation(unittest.TestCase):

  def setUp(self):
    print "\nStart MIA Server"
    self.server = SocketServer.UDPServer(('', 4080), mia_server.MiaHandler)
    server_thread = threading.Thread(target=self.server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    print "Open test sockets"
    self.s1 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.s1.settimeout(1)
    self.s2 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.s2.bind(('127.0.0.2', 0))
    self.s2.settimeout(1)

  def tearDown(self):
    print "Close test sockets"
    self.s1.close()
    self.s2.close()
    print "Stop MIA Server"
    self.server.shutdown()
    self.server.server_close()


if __name__ == '__main__':
  unittest.main(verbosity=2)
