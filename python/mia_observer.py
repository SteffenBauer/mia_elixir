#!/usr/bin/env python

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import random
import socket
import re
import time

HOST = 'localhost'
PORT = 4080

def connect_to_miaserver():
    sock.settimeout(2)
    while True:
        sock.sendto("REGISTER_SPECTATOR", (HOST, PORT))
        try:
            data = sock.recv(1024)
            if data.startswith("REGISTERED"): break
        except socket.timeout:
            print "MIA Server does not respond, retrying"
    print "Connected to MIA Server"
    sock.setblocking(1)

def retrieve_data(turn=0):
    while True:
        data = sock.recv(1024)
        if data.startswith("SCORE;"):
            _, _, scorelist = data.strip().partition(";")
            rawscores = [r.partition(":") for r in scorelist.split(",")]
            scores = [(p,s) for p,_,s in rawscores]
            turn += 1
            yield turn, scores

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
xdata = []
ydata = dict()

def init():
    ax.set_ylim(0, 100)
    ax.set_xlim(0, 20)
    del xdata[:]
    return []

fig, ax = plt.subplots()
ax.grid()
legend = plt.legend(loc=2)

def run(data):
    # update the data
    turn, scores = data
    xdata.append(turn)
    ax.clear()
    lines = []

    xmin, xmax = ax.get_xlim()
    ymin, ymax = ax.get_ylim()

    stale = False
    if turn >= xmax:
        ax.set_xlim(xmin, turn+5)
        stale = True
    if stale:
        ax.figure.canvas.draw()

    for p,s in scores:
        if p in ydata:
            ydata[p].append(s)
        else:
            ydata[p] = [s]
        lines.append(ax.plot(xdata, ydata[p], lw=1, label=p))

    return lines


if __name__ == "__main__":
    connect_to_miaserver()
    ani = animation.FuncAnimation(fig, run, retrieve_data, blit=False, interval=200,
                              repeat=False, init_func=init)
    plt.show()
