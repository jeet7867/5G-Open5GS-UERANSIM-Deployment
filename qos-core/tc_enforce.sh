#!/bin/bash
sudo tc qdisc del dev uesimtun0 root 2>/dev/null
sudo tc qdisc del dev uesimtun1 root 2>/dev/null
sudo tc qdisc del dev uesimtun2 root 2>/dev/null
sudo tc qdisc del dev uesimtun3 root 2>/dev/null

sudo tc qdisc add dev uesimtun0 root tbf rate 100mbit burst 32k latency 400ms
sudo tc qdisc add dev uesimtun1 root tbf rate 50mbit burst 32k latency 400ms
sudo tc qdisc add dev uesimtun2 root tbf rate 20mbit burst 32k latency 400ms
sudo tc qdisc add dev uesimtun3 root tbf rate 5mbit burst 32k latency 400ms

echo "QoS SLA Enforcement Applied Successfully."
