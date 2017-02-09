#!/usr/bin/env python

import socket
import re

HOST = 'localhost'
PORT = 4080

def _handle_trial(data):
  m = re.match("^(ADD|SUBTRACT|MULTIPLY):([0-9a-fA-F]{32}):([0-9:-]+)", data)
  if not m: return None
  task = m.group(1)
  uuid = m.group(2)
  numbers = [int(n) for n in m.group(3).split(':')]
  if task == "ADD": result = sum(numbers)
  elif task == "SUBTRACT": result = numbers[0] - sum(numbers[1:])
  elif task == "MULTIPLY": result = reduce(lambda x,y:x*y, numbers)
  else: result = 0
  return uuid + ":" + str(result)

def trial_client_round():
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  msg = "START"
  while True:
    print "Send", msg, "to", HOST, PORT
    sock.sendto(msg, (HOST, PORT))
    data = sock.recv(1024)
    print "Received", data
    msg = _handle_trial(data)
    if not msg: break
  sock.close()

if __name__ == "__main__":
  trial_client_round()

