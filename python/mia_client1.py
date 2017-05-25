#!/usr/bin/env python

import socket
import random

SERVERHOST = 'localhost'
SERVERPORT = 4080

LOCALIP = '127.0.0.2'
LOCALPORT = 4082
LOCALNAME = "30_PERCENT_SEE"

def higher(dice_a, dice_b):
  ad1, ad2 = dice_a[0], dice_a[1]
  bd1, bd2 = dice_b[0], dice_b[1]
  if ad1 == bd1 and ad2 == bd2: return False
  if ad1 == "2" and ad2 == "1": return True
  if bd1 == "2" and bd2 == "1": return False
  if ad1 == ad2 and bd1 == bd2: return int(ad1) > int(bd1)
  if ad1 == ad2: return True
  if bd1 == bd2: return False
  if ad1 == bd1: return int(ad2) > int(bd2)
  return int(ad1) > int(bd1)

def one_higher(dice):
  d1, d2 = dice[0],dice[1]
  if d1 == "6" and d2 == "6":
    return "2,1"
  if d1 == d2:
    return str(int(d1)+1)+","+str(int(d1)+1)
  if d1 == "6" and d2 == "5":
    return "1,1"
  if int(d1) == int(d2)+1:
    return str(int(d1)+1)+",1"
  return d1+","+str(int(d2)+1)

def connect_to_miaserver(sock):
  sock.settimeout(2)
  while True:
    sock.sendto("REGISTER;" + LOCALNAME, (SERVERHOST, SERVERPORT))
    try:
      data = sock.recv(1024)
      if "REGISTERED" in data:
        break
      else:
        print "Received '" + data + "'"
    except socket.timeout:
      print "MIA Server does not respond, retrying"
  print "Registered at MIA Server"
  sock.setblocking(1)

def play_mia(sock):
  announced = None
  while True:
    data = sock.recv(1024)
    if data.startswith("ROUND STARTING;"):
      _, _, token = data.strip().partition(";")
      sock.sendto("JOIN;" + token, (SERVERHOST, SERVERPORT))
      announced = None
    elif data.startswith("ANNOUNCED;"):
      d1, _, d2 = data.strip().split(";")[2].partition(",")
      announced = (d1, d2)
    elif data.startswith("YOUR TURN;"):
      _, _, token = data.strip().partition(";")
      if announced == None or random.uniform(0,100) > 30.0:
        sock.sendto("ROLL;" + token, (SERVERHOST, SERVERPORT))
      else:
        sock.sendto("SEE;" + token, (SERVERHOST, SERVERPORT))
    elif data.startswith("ROLLED;"):
      token = data.split(";")[2]
      d1, _, d2 = data.strip().split(";")[1].partition(",")
      if announced == None or higher((d1,d2), announced):
        sock.sendto("ANNOUNCE;"+d1+","+d2+";"+token, (SERVERHOST, SERVERPORT))
      else:
        sock.sendto("ANNOUNCE;"+one_higher(announced)+";"+token, (SERVERHOST, SERVERPORT))

def mia_client_start():
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.bind((LOCALIP, LOCALPORT))
  connect_to_miaserver(sock)
  play_mia(sock)


if __name__ == "__main__":
  mia_client_start()
