#!/usr/bin/env python

import socket
import time
import random

HOST = ''
PORT = 4080

spectator = None

names = ["player1", "player2", "player3"]
scores = [0,0,0]

if __name__ == "__main__":
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, PORT))
    while True:
        data, addr = sock.recvfrom(1024)
        if data.startswith("REGISTER_SPECTATOR"):
            print "Spectator registered from address:", addr
            spectator = addr
            sock.sendto("REGISTERED\n", addr)
            break
    for i in range(1000):
        time.sleep(0.1)
        if i == 50:
            names.append("player4")
            scores.append(0)
        lost = random.randrange(len(names))
        scores = [s+1 for s in scores]
        scores[lost] -= 1
        sock.sendto("PLAYER LOST;" + names[lost] + ";DID NOT TAKE TURN\n", addr)
        sock.sendto("SCORE;" + ",".join(n+":"+str(s) for n,s in zip(names, scores)) + "\n", addr)
    sock.close()
