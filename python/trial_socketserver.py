#!/usr/bin/env python

# Trial server program
import SocketServer
import uuid
import random
import re

HOST = ''                 # Symbolic name meaning all available interfaces
PORT = 4080               # Arbitrary non-privileged port

trials = []  # trial struct { "addr": addr, "uuid": uuid, "solution": solution,
             #                "trials": num, "correct": num, "wrong": num}
class TrialHandler(SocketServer.BaseRequestHandler):

  def handle(self):
    data, socket = self.request
    print "Received", data.strip(), "from", self.client_address
    response = self._handle_packet(self.client_address, data.strip())
    if response:
      socket.sendto(response, self.client_address)
    else:
      print "No response"

  def _handle_packet(self, addr, data):
    if data == "START":
      response = self._new_trial(data, addr)
    else:
      response = self._handle_solution(data, addr)
    return response

  def _update_trial(self, trial, solution):
    trial["trials"] -= 1
    if trial["solution"] == int(solution):
      trial["correct"] += 1
    else:
      trial["wrong"] += 1
    return trial

  def _determine_result(self, trial):
    if trial["wrong"] == 0:
      ret = "ALL CORRECT"
    else:
      ret = str(trial["wrong"]) + " WRONG " + str(trial["correct"]) + " CORRECT"
    return ret

  def _handle_solution(self, data, addr):
    m = re.match("^([0-9a-fA-F]{32}):(-?[0-9]+)", data)
    if m:
      u, sol = m.group(1), m.group(2)
      for i, t in enumerate(trials):
        if t["addr"] == addr and t["uuid"] == u:
          t = self._update_trial(t, sol)
          if t["trials"] == 0:
            return self._determine_result(trials.pop(i))
          else:
            newtrial, t["uuid"], t["solution"] = self._generate_trial()
            return newtrial
    return None

  def _generate_uuid(self):
    return uuid.uuid4().hex

  def _generate_trial(self):
    u = self._generate_uuid()
    n = 2 + random.randrange(4)
    nums = [1 + random.randrange(200) for _ in range(n)]
    ty = ["ADD", "SUBTRACT", "MULTIPLY"][random.randrange(3)]
    if ty == "ADD":         solution = sum(nums)
    elif ty == "SUBTRACT":  solution = nums[0] - sum(nums[1:])
    else:                   solution = reduce(lambda x,y:x*y, nums)
    trial = ty + ":" + u + ":" + ":".join(str(x) for x in nums)
    return trial, u, solution

  def _new_trial(self, data, addr):
    if any(t for t in trials if t["addr"] == addr):
      return None
    trial, uuid, solution = self._generate_trial()
    trials.append({"addr": addr, "uuid": uuid, "solution": solution,
              "trials": 5, "correct": 0, "wrong": 0})
    return trial

if __name__ == "__main__":
    trial_server = SocketServer.UDPServer((HOST, PORT), TrialHandler)
    trial_server.serve_forever()
