#!/usr/bin/env python

# Echo server program
import socket

HOST = ''                 # Symbolic name meaning all available interfaces
PORT = 4080               # Arbitrary non-privileged port
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind((HOST, PORT))
while 1:
    data, addr = s.recvfrom(1024)
    print "Received", data.strip(), "from", addr
    s.sendto(data, addr)
s.close()
