#!/usr/bin/env python

import unittest
import threading
import SocketServer
import socket
import echo_socketserver

class TestEchoServer(unittest.TestCase):

  def setUp(self):
    print "\nStart Echo Server"
    self.server = SocketServer.UDPServer(('', 4080), echo_socketserver.MyUDPHandler)
    server_thread = threading.Thread(target=self.server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

  def tearDown(self):
    print "Stop Echo Server"
    self.server.shutdown()
    self.server.server_close()

  def test_interaction(self):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto("SOMETHING", ('localhost', 4080))
    data = s.recv(1024)
    self.assertEqual(data, "SOMETHING")
    s.sendto("", ('localhost', 4080))
    data = s.recv(1024)
    self.assertEqual(data, "")
    s.close()

  def test_two_clients(self):
    s1 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s2 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s1.sendto("FIRST_MESSAGE", ('localhost', 4080))
    s2.sendto("SECOND_MESSAGE", ('localhost', 4080))
    data2, data1 = s2.recv(1024), s1.recv(1024)
    self.assertEqual(data1, "FIRST_MESSAGE")
    self.assertEqual(data2, "SECOND_MESSAGE")
    s1.close()
    s2.close()

if __name__ == '__main__':
  unittest.main(verbosity=2)
