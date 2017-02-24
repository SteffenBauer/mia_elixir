#!/usr/bin/env python

HOST = ''
PORT = 4080

DEBUG = True

def handle_packet(sock, addr, data):
  if data.startswith("REGISTER;"):
    response = register_player(data, addr)
  elif data.startswith("REGISTER_SPECTATOR"):
    response = register_spectator(data, addr)

  if response:
    if DEBUG: print "Replying '",response,"'"
    sock.sendto(response, addr)
  else:
    if DEBUG: print "No response"

def mia_server_start():
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.bind((HOST, PORT))
  while 1:
    try:
      data, addr = sock.recvfrom(1024)
      if DEBUG: print "Received", data.strip(), "from", addr
      handle_packet(sock, addr, data.strip())
    except KeyboardInterrupt:
      print "Shutting down server"
      break
    except: pass
  s.close()

if __name__ == "__main__":
    mia_server_start()
