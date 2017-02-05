#!/usr/bin/env python

# Trial server program
import socket
import uuid
import random
import re

HOST = ''                 # Symbolic name meaning all available interfaces
PORT = 4080               # Arbitrary non-privileged port

trials = []  # trial struct { "addr": addr, "uuid": uuid, "solution": solution,
             #                "trials": num, "correct": num, "wrong": num}

def update_trial(trial, solution):
  trial["trials"] -= 1
  if trial["solution"] == int(solution): 
    trial["correct"] += 1
  else:
    trial["wrong"] += 1
  return trial
  
def determine_result(trial):
  if trial["wrong"] == 0:
    ret = "ALL CORRECT"
  else:
   ret = str(trial["wrong"]) + " WRONG " + str(trial["correct"]) + " CORRECT"
  return ret

def handle_solution(data, addr):
  m = re.match("^([0-9a-fA-F]{32}):(-?[0-9]+)", data)
  if m:
    u, sol = m.group(1), m.group(2)
    for i, t in enumerate(trials):
      if t["addr"] == addr and t["uuid"] == u:
        t = update_trial(t, sol)
        if t["trials"] == 0:
          return determine_result(trials.pop(i))
        else:
          newtrial, t["uuid"], t["solution"] = generate_trial()
          return newtrial
  return None

def generate_uuid():
  return uuid.uuid4().hex

def generate_trial():
  u = generate_uuid()
  n = 2 + random.randrange(4)
  nums = [1 + random.randrange(200) for _ in range(n)]
  ty = ["ADD", "SUBTRACT", "MULTIPLY"][random.randrange(3)]
  if ty == "ADD":         solution = sum(nums)
  elif ty == "SUBTRACT":  solution = nums[0] - sum(nums[1:])
  else:                   solution = reduce(lambda x,y:x*y, nums)
  trial = ty + ":" + u + ":" + ":".join(str(x) for x in nums)
  return trial, u, solution

def new_trial(data, addr):
  if any(t for t in trials if t["addr"] == addr):
    return None
  trial, uuid, solution = generate_trial()
  trials.append({"addr": addr, "uuid": uuid, "solution": solution, 
            "trials": 5, "correct": 0, "wrong": 0})
  return trial

def handle_packet(sock, addr, data):
  if data == "START":
    response = new_trial(data, addr)
  else:
    response = handle_solution(data, addr)

  if response:
    sock.sendto(response, addr)
  else:
    print "No response"

def trial_server_start():
  s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  s.bind((HOST, PORT))
  while 1:
    try:
      data, addr = s.recvfrom(1024)
      print "Received", data.strip(), "from", addr
      handle_packet(s, addr, data.strip())
      print "Debug:", trials
    except KeyboardInterrupt:
      print "Shutting down server"
      break
    except: pass
  s.close()

if __name__ == "__main__":
    trial_server_start()

