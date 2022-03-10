#!/usr/bin/python3

import os
import sys
import json

if __name__ == '__main__':
    filename = sys.argv[1]
    fp = open(filename, 'r')
    js = json.load(fp)
    best_actions = {}
    for agent, q_table in js.items():
        best_actions[int(agent)] = {}
        for state, actions in q_table.items():
            action = int(max(actions.items(), key=lambda kv: kv[1])[0])
            best_actions[int(agent)][int(state)] = action
    for agent, actions in best_actions.items():
        print(f"Agent #{agent}")
        for state, action in actions.items():
            print(f"{state}: {action}")
        print("\n")
