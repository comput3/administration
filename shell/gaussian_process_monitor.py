#!/usr/bin/env python3
import psutil
import time
import statistics

class Stack:
    def __init__(self, max_size=120):
        self.stack = []
        self.max_size = max_size

    def push(self, item):
        self.stack.append(item)
        if len(self.stack) > self.max_size:
            self.stack.pop(0)

    def check_alert(self):
        if len(self.stack) >= self.max_size:
            z = self.calculate_zscore(self.stack[-1])
            if z >= 2:
                print("ALERT: PID: {}, Z-score is greater than or equal to 2 standard deviations from the mean".format(self.pid))

    def calculate_zscore(self, value):
        mean = statistics.mean(self.stack)
        standard_deviation = statistics.stdev(self.stack)
        if standard_deviation == 0:
            return 0
        z = (value - mean) / standard_deviation
        return z

def monitor_processes():
    all_stacks = {}
    while True:
        for proc in psutil.process_iter():
            try:
                cmdline = ' '.join(proc.cmdline())
                if 'security_passthrough' in cmdline:
                    pid = proc.pid
                    cpu_percent = proc.cpu_percent()
                    if pid not in all_stacks:
                        all_stacks[pid] = Stack()
                        all_stacks[pid].pid = pid
                    stack = all_stacks[pid]
                    stack.push(cpu_percent)
                    stack.check_alert()
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
        print("All Stacks: ", [[stack.pid, stack.stack] for stack in all_stacks.values()])
        time.sleep(30)

if __name__ == "__main__":
    monitor_processes()
