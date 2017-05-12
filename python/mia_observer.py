#!/usr/bin/env python

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import random

def data_gen(t=0):
    value1 = 50
    value2 = 50
    while True:
        yield t, value1, value2
        value1 += random.randint(-2,2)
        value2 += random.randint(-2,2)
        t += 1

def init():
    ax.set_ylim(0, 100)
    ax.set_xlim(0, 20)
    del xdata[:]
    del y1data[:]
    del y2data[:]
    line1.set_data(xdata, y1data)
    line2.set_data(xdata, y2data)
    return (line1, line2)

fig, ax = plt.subplots()
line1, = ax.plot([], [], lw=2, label="Line 1")
line2, = ax.plot([], [], lw=2, label="Line 2")
ax.grid()
legend = plt.legend(loc=2)
xdata, y1data, y2data = [], [], []

def run(data):
    # update the data
    t, y1, y2 = data
    xdata.append(t)
    y1data.append(y1)
    y2data.append(y2)
    xmin, xmax = ax.get_xlim()
    ymin, ymax = ax.get_ylim()

    if t >= xmax:
        ax.set_xlim(xmin, xmax+1)
        ax.figure.canvas.draw()
    if y1 >= ymax or y2 >= ymax:
        ax.set_ylim(ymin, max(y1,y2)+1)
        ax.figure.canvas.draw()
    if y1 <= ymin or y2 <= ymin:
        ax.set_ylim(min(y1,y2)-1, ymax)
        ax.figure.canvas.draw()

    line1.set_data(xdata, y1data)
    line2.set_data(xdata, y2data)

    legend.get_texts()[0].set_text("Line 1:" + str(y1))
    legend.get_texts()[1].set_text("Line 2:" + str(y2))

    return (line1, line2)

ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=200,
                              repeat=False, init_func=init)

if __name__ == "__main__":
    plt.show()

