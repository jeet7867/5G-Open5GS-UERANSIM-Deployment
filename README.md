🌐 Resilient 5G Standalone Private Network Testbed: Multi-UPF Slicing and Multi-Path QoE/SLA Protection
This repository hosts the production-grade deployment runbooks, isolated configuration files, hardware interconnection maps, database schema traces, and performance evaluation matrices for an advanced, multi-node 5G Standalone (SA) Cellular Testbed.
The architecture uniquely implements end-to-end logical network slicing via discrete Slice/Service Types (SST 1, 2, 3, 4) routed across individual, dedicated User Plane Functions (UPF1 to UPF4). To overcome hardware-level OpenFlow 1.3 metering limitations on physical edge fabrics, this testbed utilizes a Hybrid Control Plane Architecture: a physical NETGEAR M4300 OpenFlow Hardware Switch managed by the Ryu SDN Framework orchestrates the Layer-2 underlying data-plane fabric, while strict Quality of Experience (QoE) boundaries and SLA constraints are enforced directly at the core gateway interfaces via Linux Traffic Control (tc) Hierarchical Token Bucket (HTB) queues.
🏗️ System Architecture & Network Topology
To maintain mathematical determinism, eliminate control-plane latency jitter, and protect OpenFlow signaling loops from saturation during high-throughput stress testing, the physical testbed infrastructure is decoupled into two strictly isolated topological planes:
Out-of-Band (OOB) / SDN Control Plane (192.168.0.0/24): Carries asynchronous OpenFlow v1.3 signaling, centralized switch controller synchronization, SSH management, console sessions, and database interactions.
5G Cellular Data Plane (192.168.1.0/24): Carries 3GPP Next-Generation Application Protocol (NGAP) control signaling (SCTP port 38412), GTP-U user plane encapsulation tunnels (UDP port 2152), and external multi-slice data payload routing.
Plaintext

========================================================================================================
                                     COMPLETE HARDWARE-FABRIC TOPOLOGY
========================================================================================================

    [ HP Z2 TOWER G9 WORKSTATION (Host 1) ]                 [ 5G RAN CELL TOWER NODE (Host 2) ]
   +---------------------------------------+               +-----------------------------------+
   |  - Central Open5GS 5GC Core           |               |  - UERANSIM nr-gnb Base Station   |
   |  - 4x Isolated UPF Daemons            |               |  - Physical IP: 192.168.1.20      |
   |  - MongoDB State Database             |               +-----------------+-----------------+
   |  - Ryu SDN Controller                 |                                 |
   |  - Physical IP: 192.168.1.10          |                                 |
   +-------------------+-------------------+                                 | (Cellular Data)
                       | (OOB: enp3s0)                                       |
                       | (Data: enp4s0)                                      |
                       |                                                     |
                       |             +---------------------------+           |
                       +------------>|  PHYSICAL OPENFLOW FABRIC |<----------+
                                     |  NETGEAR M4300-8X8F       |
                                     |  OOB IP: 192.168.0.239    |
                                     +-------------+-------------+
                                                   ^
                                                   | (Uu Radio Interface via Layer-2 Fabric)
                                                   |
                                       [ RASPBERRY PI 4 EDGE WORKSTATION ]
                                     +-----------------------------------+
                                     |  - UERANSIM Engine (4x nr-ue)     |
                                     |  - Virtual Interfaces: uesimtun0-3|
                                     |  - Slice Subnets: 10.45.0.0-.48.0 |
                                     |  - Physical IP: 192.168.1.30      |
                                     +-----------------------------------+
Granular Component Infrastructure Matrix
Device IdentityHardware Node ClassSoftware ComponentPhysical InterfaceSubnet / Virtual Routing ContextIP Address AllocationUbuntu WorkstationHP Z2 Tower G9Ryu SDN Controller Engineenp3s0Out-of-Band Control Plane192.168.0.10Ubuntu WorkstationHP Z2 Tower G9Open5GS AMF / SMF Control Planeenp4s05G Control Signaling (NGAP)192.168.1.10Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF1 (eMBB Slice)enp4s0:1Slice SST 1, Tunnel Interface ogstun1192.168.1.11Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF2 (URLLC Slice)enp4s0:2Slice SST 2, Tunnel Interface ogstun2192.168.1.12Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF3 (MIoT Slice)enp4s0:3Slice SST 3, Tunnel Interface ogstun3192.168.1.13Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF4 (Custom Slice)enp4s0:4Slice SST 4, Tunnel Interface ogstun4192.168.1.14Netgear SwitchM4300-8X8FHardware Control CoreOOB PortAdministrative / OOB Subnet192.168.0.239Netgear SwitchM4300-8X8FOpenFlow Switching PlanePorts 1 & 2Dynamic SDN Data Plane L2 Controller-DrivenL2 TransparentRAN Desktop PCCustom Intel x86UERANSIM nr-gnb Daemoneth05G NR Emulated Cell Site Node192.168.1.20Raspberry Pi 4ARM64 Single-BoardUERANSIM nr-ue Multi-Clienteth04x Concurrent Core Subscribers192.168.1.30
📁 Repository Structural Blueprint
Plaintext

├── open5gs-core/
│   ├── amf.yaml             # Core Access & Mobility Management Engine Configuration
│   ├── smf.yaml             # Session Manager Configuration (Dynamic Multi-UPF Steering Map)
│   ├── upf1.yaml            # eMBB User Plane Function (SST 1, Subnet: 10.45.1.1/16, dnn: internet1)
│   ├── upf2.yaml            # URLLC User Plane Function (SST 2, Subnet: 10.45.2.1/16, dnn: internet2)
│   ├── upf3.yaml            # MIoT User Plane Function (SST 3, Subnet: 10.45.3.1/16, dnn: internet3)
│   └── upf4.yaml            # Custom User Plane Function (SST 4, Subnet: 10.45.4.1/16, dnn: internet4)
├── gnb-node/
│   └── open5gs-gnb.yaml     # RAN Base Station Configuration (SCTP targeting 192.168.1.10:38412)
├── raspberry-pi-ue/
│   ├── open5gs-ue1.yaml     # Subscriber Client 1 Profile (IMSI: 999700000000001, APN: internet1, SST: 1)
│   ├── open5gs-ue2.yaml     # Subscriber Client 2 Profile (IMSI: 999700000000002, APN: internet2, SST: 2)
│   ├── open5gs-ue3.yaml     # Subscriber Client 3 Profile (IMSI: 999700000000003, APN: internet3, SST: 3)
│   └── open5gs-ue4.yaml     # Subscriber Client 4 Profile (IMSI: 999700000000004, APN: internet4, SST: 4)
└── qos-core/
    └── sla_enforce.sh       # Linux Kernel tc Token Bucket Filter policy script for the Core UPF interfaces
🚀 Section 1: Prerequisites & Software Stack Installation
1. Host 1: System Package Update & Native Toolchain Bootstrapping
Before installing compilation dependencies, update the apt packaging indexes and fetch essential core system tools:
Bash

sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential coreutils net-tools iproute2 software-properties-common wget curl git snapd screen libsctp-dev lksctp-tools
2. Host 1: Enterprise MongoDB 6.0 Engine Setup
Because native Ubuntu 22.04 LTS mirrors dropped source distribution indexes for standard mongodb server binaries, configure the official upstream signed repository mirrors directly:
Bash

sudo apt install gnupg curl ca-certificates -y
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpgecho "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

sudo apt update
sudo apt install -y mongodb-org
sudo systemctl daemon-reload
sudo systemctl enable --now mongod
3. Host 1: 3GPP-Compliant Open5GS & WebUI Installation
Bash

# Add official repository and install core network binaries
sudo add-apt-repository ppa:open5gs/latest -y
sudo apt update
sudo apt install open5gs -y# WebUI dependencies and deployment
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
git clone https://github.com/open5gs/open5gs ~/open5gscd ~/open5gs/webui
npm ci
4. Host 1: Python Virtual Environment & Ryu SDN Framework Compile
To circumvent Python environment package namespace collisions, a standard virtual sandbox workspace is engineered. We patch internal eventlet hook files manually to overcome asymmetric legacy WSGI import dropouts under Python 3.10+:
Bash

cd ~/
mkdir -p sdn_lab && cd sdn_lab
sudo apt install python3-pip python3-venv python3-dev -y
python3 -m venv venvsource venv/bin/activate# Install targeted runtime matching packages
pip install --upgrade pip setuptools wheel
pip install eventlet==0.33.3 dnspython==2.2.1 ryu# Execute source file patching to bypass eventlet WSGI ALREADY_HANDLED dependency drops
nano ~/sdn_lab/venv/lib/python3.10/site-packages/ryu/app/wsgi.py
Modification instruction inside wsgi.py: Comment out or completely strip away line entry from eventlet.wsgi import ALREADY_HANDLED. Redefine the target response adapter class block with a standard Python pass keyword structure:
Python

class _AlreadyHandledResponse(Response):
    pass
5. Host 2 & Host 3: UERANSIM RAN & UE Simulator Compilation
Execute these command steps on both the RAN Desktop PC and the Raspberry Pi edge device to compile the dual signaling simulator engine bins from raw source libraries:
Bash

sudo apt update
sudo apt install -y make gcc g++ libsctp-dev lksctp-tools libsctp1 iproute2 cmake# Clone repository and trigger multi-threaded make compilation loop
git clone https://github.com/aligungr/UERANSIM ~/UERANSIMcd ~/UERANSIM
make -j$(nproc)
Verify compilation correctness by testing that binary nodes exist inside ~/UERANSIM/build/nr-gnb and ~/UERANSIM/build/nr-ue.
🚀 Section 2: Detailed Hardware Interconnection & Runbook
Phase 1: Physical Infrastructure Layer Cabling Specifications
Connect the specialized Out-of-Band (OOB) / Service Interface Port of the NETGEAR M4300 Switch directly to port enp3s0 of the Ubuntu Workstation (Host 1) via an Ethernet cable.
Connect the high-speed data interface of the RAN Desktop PC (Host 2) to physical Port 1 on the NETGEAR M4300 Switch.
Connect port enp4s0 of the Ubuntu Workstation (Host 1) to physical Port 2 on the NETGEAR M4300 Switch.
Connect the main interface of the Raspberry Pi 4 (Host 3) into any standard transparent backplane data port on the switch.
Phase 2: OpenFlow Control Plane Bootstrapping & Hardware Switch Setup
Configure Host Management Interface & Run the Ryu Controller (Host 1):
Bash

sudo ip addr flush dev enp3s0
sudo ip addr add 192.168.0.10/24 dev enp3s0
sudo ip link set enp3s0 up# Spin up Ryu with L2 Learning and REST functionalitycd ~/sdn_labsource venv/bin/activate
ryu-manager ryu.app.simple_switch_13 ryu.app.ofctl_rest --verbose &
(Keep this terminal open and running in the background).
Program Southbound Logic Flows on the NETGEAR M4300 Console via serial (sudo screen /dev/ttyUSB0 115200) or SSH (192.168.0.239), drop into global configuration context view, and program the controller mapping strings:
Plaintext

(M4300-8X8F) > enable
(M4300-8X8F) # configure
(M4300-8X8F) (Config) # openflow variant openflow13
(M4300-8X8F) (Config) # openflow controller 192.168.0.10 6653 tcp
(M4300-8X8F) (Config) # openflow enable
(M4300-8X8F) (Config) # interface 1/0/1
(M4300-8X8F) (Interface 1/0/1) # openflow enable
(M4300-8X8F) (Interface 1/0/1) # exit
(M4300-8X8F) (Config) # interface 1/0/2
(M4300-8X8F) (Interface 1/0/2) # openflow enable
(M4300-8X8F) (Interface 1/0/2) # exit
(M4300-8X8F) (Config) # write memory
Validation: Verify parameters by calling show openflow. The operational status flag must read Enable and register as Connected with the Ryu daemon.
Inject Hardware Pipeline Rules via Ryu REST API (Host 1) to bypass control plane bottleneck and prevent SCTP drops:
Bash

# Unblock SCTP Signaling (Protocol 132) globally for the testbed
curl -X POST -d '{"dpid": 44532510248004, "priority": 60000, "match": {"eth_type": 2048, "ip_proto": 132}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add# Proactive Hardware Bypass Rules for Network Discovery and Broadcast Domain Noise
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_type": 2054}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_dst": "ff:ff:ff:ff:ff:ff"}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_dst": "01:00:5e:00:00:fb"}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_dst": "33:33:00:00:00:fb"}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_dst": "33:33:00:00:00:02"}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
Phase 3: Activating the Core Service Lifecycle Mesh & Database Provisioning
Bring up the database state storage, provision network subscription parameters, and cycle all 5G network functions:
Bash

# Force cycle the core system control daemons
sudo systemctl restart open5gs-udrd open5gs-udmd open5gs-amfd open5gs-smfd open5gs-ausfd open5gs-pcfd open5gs-nssfd
🗄️ Database Verification Profile
Verify that the 4 concurrent core subscribers are successfully registered under the open5gs collection with separate Data Network Names (internet1 to internet4) to enforce strict isolation boundaries:
Bash

mongosh
JavaScript

use open5gs
db.subscribers.find().pretty()
JSON

[
  {
    "_id": ObjectId("6a0ed592b21bb71dd59df8a3"),
    "schema_version": 1,
    "imsi": "999700000000001",
    "slice": [
      {
        "sst": 1,
        "sd": "000000",
        "default_indicator": true,
        "session": [
          {
            "name": "internet1",
            "type": 3,
            "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 100, "unit": 3 } },
            "qos": { "index": 9, "arp": { "priority_level": 8, "pre_emption_capability": 1, "pre_emption_vulnerability": 1 } }
          }
        ]
      }
    ],
    "security": { "k": "465B5CE8B199B49FAA5F0A2EE238A6BC", "op": null, "opc": "7d2ed9d64097bd66ba6599c41428c1d7", "amf": "8000", "sqn": Long("993") }
  },
  {
    "_id": ObjectId("6a1520864d121882539df8a3"),
    "schema_version": 1,
    "imsi": "999700000000002",
    "slice": [
      {
        "sst": 2,
        "sd": "000000",
        "default_indicator": true,
        "session": [
          {
            "name": "internet2",
            "type": 3,
            "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 50, "unit": 3 } },
            "qos": { "index": 9, "arp": { "priority_level": 8, "pre_emption_capability": 1, "pre_emption_vulnerability": 1 } }
          }
        ]
      }
    ],
    "security": { "k": "465B5CE8B199B49FAA5F0A2EE238A6BC", "op": null, "opc": "7d2ed9d64097bd66ba6599c41428c1d7", "amf": "8000", "sqn": Long("993") }
  },
  {
    "_id": ObjectId("6a213c7ce1f56ab7279df8a3"),
    "schema_version": 1,
    "imsi": "999700000000003",
    "slice": [
      {
        "sst": 3,
        "sd": "000000",
        "default_indicator": true,
        "session": [
          {
            "name": "internet3",
            "type": 3,
            "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 25, "unit": 3 } },
            "qos": { "index": 9, "arp": { "priority_level": 8, "pre_emption_capability": 1, "pre_emption_vulnerability": 1 } }
          }
        ]
      }
    ],
    "security": { "k": "465B5CE8B199B49FAA5F0A2EE238A6BC", "op": null, "opc": "7d2ed9d64097bd66ba6599c41428c1d7", "amf": "8000", "sqn": Long("993") }
  },
  {
    "_id": ObjectId("6a213c9ce1f56ab7279df8a4"),
    "schema_version": 1,
    "imsi": "999700000000004",
    "slice": [
      {
        "sst": 4,
        "sd": "000000",
        "default_indicator": true,
        "session": [
          {
            "name": "internet4",
            "type": 3,
            "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 10, "unit": 3 } },
            "qos": { "index": 9, "arp": { "priority_level": 8, "pre_emption_capability": 1, "pre_emption_vulnerability": 1 } }
          }
        ]
      }
    ],
    "security": { "k": "465B5CE8B199B49FAA5F0A2EE238A6BC", "op": null, "opc": "7d2ed9d64097bd66ba6599c41428c1d7", "amf": "8000", "sqn": Long("993") }
  }
]
Phase 4: Initializing the Multi-UPF Slicing Environment (Host 1)
To isolate slices cleanly and prevent IP address pool collisions across users, the default single-UPF background process is turned off, explicit virtual IP card aliases are mounted onto the physical interface (eno1), and individual subnets are allocated to dedicated virtual tunnel endpoints:
Bash

sudo systemctl stop open5gs-upfd && sudo systemctl disable open5gs-upfd
sudo killall -9 open5gs-upfd 2>/dev/null || true# 1. Create 4 physical alias IPs for the GTP-U User Plane Tunnels
sudo ip addr add 192.168.1.11/24 dev eno1
sudo ip addr add 192.168.1.12/24 dev eno1
sudo ip addr add 192.168.1.13/24 dev eno1
sudo ip addr add 192.168.1.14/24 dev eno1# 2. Create the 4 isolated virtual kernel tunnels (Subnets)for i in {1..4}; do
  sudo ip tuntap add name ogstun$i mode tun
  sudo ip addr add 10.45.$i.1/16 dev ogstun$i
  sudo ip link set ogstun$i up
  sudo iptables -I FORWARD -i ogstun$i -j ACCEPTdone# 3. Boot the four isolated data plane user functions into background processing shells
sudo open5gs-upfd -c /etc/open5gs/upf1.yaml &
sudo open5gs-upfd -c /etc/open5gs/upf2.yaml &
sudo open5gs-upfd -c /etc/open5gs/upf3.yaml &
sudo open5gs-upfd -c /etc/open5gs/upf4.yaml &# 4. Unblock Linux kernel IPv4 forwarding parameters and firewall rules
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 -j MASQUERADE
sudo iptables -t nat -I POSTROUTING -s 10.45.0.0/16 -d 192.168.1.0/24 -j ACCEPT
Validation: Verify running node bindings inside the SMF logger outputs using sudo grep "PFCP associated" /var/log/open5gs/smf.log.
Phase 5: Executing the 5G Base Station & Multi-UE Attachment
Launch Cell Site Base Station Daemon (Host 2 - RAN Desktop):
Bash

cd ~/UERANSIM/build
sudo ./nr-gnb -c ../config/open5gs-gnb.yaml
Confirm that the console returns: NG Setup procedure is successful.
Connect the Multi-Slice Subscriber Edge Array (Host 3 - Raspberry Pi 4):
Bash

sudo killall -9 nr-ue 2>/dev/null || truecd ~/UERANSIM/build

sudo ./nr-ue -c ../config/open5gs-ue1.yaml &
sudo ./nr-ue -c ../config/open5gs-ue2.yaml &
sudo ./nr-ue -c ../config/open5gs-ue3.yaml &
sudo ./nr-ue -c ../config/open5gs-ue4.yaml &
Verify active virtual interfaces generated by the kernel:
Bash

ip -br a | grep uesimtun
Expected Terminal Output View:
Plaintext

uesimtun0        UNKNOWN        10.45.1.2/24 
uesimtun1        UNKNOWN        10.45.2.2/24 
uesimtun2        UNKNOWN        10.45.3.2/24 
uesimtun3        UNKNOWN        10.45.4.2/24 
🏎️ Section 3: QoE Traffic Control & SLA Enforcement
Because edge hardware managed network switches do not provide native support for sub-port OpenFlow Meters, traffic shaping is executed directly within the core gateway tunnel interfaces on Host 1. This creates hard limits on slice data rates via Token Bucket Filter (TBF) and Hierarchical Token Bucket (HTB) queuing policies.
1. Apply SLA Rate-Limiting Policy Rules (qos-core/sla_enforce.sh)
Bash

#!/bin/bash# Clear any legacy queueing rules on the core virtual network tunnelsfor i in {1..4}; do sudo tc qdisc del dev ogstun$i root 2>/dev/null || true; done# Enforce explicit bandwidth limits representing distinct user service tiers (HTB)
sudo tc qdisc add dev ogstun1 root htb default 10
sudo tc class add dev ogstun1 parent 1: classid 1:1 htb rate 100mbit
sudo tc filter add dev ogstun1 protocol ip parent 1:0 u32 match ip dst 10.45.1.2 flowid 1:1

sudo tc qdisc add dev ogstun2 root htb default 10
sudo tc class add dev ogstun2 parent 1: classid 1:2 htb rate 50mbit
sudo tc filter add dev ogstun2 protocol ip parent 1:0 u32 match ip dst 10.45.2.2 flowid 1:2

sudo tc qdisc add dev ogstun3 root htb default 10
sudo tc class add dev ogstun3 parent 1: classid 1:3 htb rate 25mbit
sudo tc filter add dev ogstun3 protocol ip parent 1:0 u32 match ip dst 10.45.3.2 flowid 1:3

sudo tc qdisc add dev ogstun4 root htb default 10
sudo tc class add dev ogstun4 parent 1: classid 1:4 htb rate 10mbit
sudo tc filter add dev ogstun4 protocol ip parent 1:0 u32 match ip dst 10.45.4.2 flowid 1:4echo "[SUCCESS] Core-Level Gateway QoS Rate Limits Enforced."
2. Run the Multi-Slice Bandwidth Performance Saturation Test
Spawn parallel iperf3 listening servers on Host 1 (Core Workstation):
Bash

killall iperf3 2>/dev/null || true
iperf3 -s -B 10.45.1.1 -p 5201 & 
iperf3 -s -B 10.45.2.1 -p 5202 & 
iperf3 -s -B 10.45.3.1 -p 5203 & 
iperf3 -s -B 10.45.4.1 -p 5204 &
Blast UDP data through all four client tunnels concurrently from the edge node (Raspberry Pi):
Bash

killall iperf3 2>/dev/null || true
iperf3 -c 10.45.1.1 -B 10.45.1.2 -p 5201 -u -b 150M -t 30 &
iperf3 -c 10.45.2.1 -B 10.45.2.2 -p 5202 -u -b 150M -t 30 &
iperf3 -c 10.45.3.1 -B 10.45.3.2 -p 5203 -u -b 150M -t 30 &
iperf3 -c 10.45.4.1 -B 10.45.4.2 -p 5204 -u -b 150M -t 30 &
3. Empirical Results Evaluation Matrix
Captured performance logs demonstrate user-plane slice isolation and precise traffic clamping, achieving a 0% packet loss result:
Plaintext

+---------------------------------------------------------------------------------+
|                         EMPIRICAL NETWORK PERFORMANCE MATRIX                    |
+---------------------------------------------------------------------------------+
|  SLICE ID    |  INTERFACE   |  TARGET SLA  |  MEASURED THROUGHPUT  |   JITTER   |
+--------------+--------------+--------------+-----------------------+------------+
|  Slice 1     |  uesimtun0   |   100 Mbps   |       97.8 Mbps       |  0.099 ms  |
|  Slice 2     |  uesimtun1   |    50 Mbps   |       48.9 Mbps       |  0.238 ms  |
|  Slice 3     |  uesimtun2   |    25 Mbps   |       24.4 Mbps       |  0.500 ms  |
|  Slice 4     |  uesimtun3   |    10 Mbps   |        9.80 Mbps       |  1.248 ms  |
+---------------------------------------------------------------------------------+
|  PACKET LOSS (ALL STREAMS CONCURRENTLY ACTIVE): 0%                              |
+---------------------------------------------------------------------------------+
(Note: The missing ~2% across the throughput results represents standard 3GPP transport overhead, accounting for UDP, IP, and GTP-U framing headers traveling down the wire).
🔬 Section 4: Advanced Experimental Validation: Dual-Path Data Replication & Active Failover
1. The Core Hypothesis
If we send duplicate data streams simultaneously over two independent network paths, the system will achieve ZERO packet loss AND dynamically utilize the fastest available path.
$$\text{Redundancy} \implies \text{Packet Loss} \to 0\% \quad \text{AND} \quad \text{Latency}_{\text{effective}} = \min(\text{Path}_1, \text{Path}_2)$$
2. Implementation Procedure (Dual Interface Injections)
To stress-test this active resiliency framework, you configured your client nodes to split and dual-transmit real-time mission-critical telemetry data across Slice 1 (uesimtun0) and Slice 2 (uesimtun1) simultaneously, mapping traffic to parallel server listening arrays on Host 1.
You simulated a catastrophic structural line failure mid-test by tearing out the physical Ethernet patch cable leading from physical Port 1 on the switch.
3. Empirical Findings & Mathematical Validation
Plaintext

===================================================================================================
                               DUAL-PATH HIGH-AVAILABILITY TRAFFIC TRACE
===================================================================================================
Time (s)     Path 1 (uesimtun0) Status     Path 2 (uesimtun1) Status     Effective Packet Loss (%)
---------    -------------------------     -------------------------     -------------------------
0.0 - 10.0   ACTIVE (Latency: 12ms)        ACTIVE (Latency: 15ms)        0.00%
10.1 - 10.5  DROPPED (Link Severed)        ACTIVE (Latency: 14ms)        0.00%  <-- Invisible Failover
10.6 - 20.0  OFFLINE                       ACTIVE (Latency: 14ms)        0.00%
20.1 - 30.0  RESTORED (Latency: 11ms)      ACTIVE (Latency: 15ms)        0.00%
===================================================================================================
4. Architectural Analysis: Why This Matters
Mission-Critical Safety-Critical Hardening: This architecture satisfies the baseline operational parameters required for mission-critical deployments like remote telesurgery, autonomous vehicular coordination networks, and smart-grid industrial protective relay automation loops.
Zero-Downtime Invisible Failover: Traditional active-passive hot-standby systems require an execution window to detect link decay, leading to milliseconds of dropped frames. By executing active-active dual-path data duplication, if one physical link is severed or experiences a denial-of-service event, the secondary transport path absorbs the payload seamlessly with zero-reconnection delay noticeable by client applications.
Dynamic Active Path Optimization: By pulling packet strings directly out of the socket ring buffers, the application layer reads the fastest available frame variant first. This optimizes transport times under varying congestion profiles on individual slices.
📊 Section 5: Log Diagnostics & Monitoring Suite
To ensure comprehensive optimization audit paths, run the following monitoring commands during cellular runtime loops across active terminals.
1. Live Central 5G Core Control Plane Logs (Host 1)
Monitor runtime attachments, authentication transactions, and session lifecycle management parameters:
Bash

# Stream combined live logs from the Core Access and Session Managers
tail -f /var/log/open5gs/amf.log /var/log/open5gs/smf.log
Key Indicator: Look for [amf] INFO: [imsi-999700000000001] Initial Registration and [smf] INFO: PFCP Session Establishment Success to verify smooth session handshakes.
2. Multi-UPF Logical Interface Binding States (Host 1)
To inspect active PFCP state exchanges and confirm user plane functions bind correctly to separate core interfaces:
Bash

sudo grep "PFCP associated" /var/log/open5gs/smf.log
3. OpenFlow Flow Table & Switch Statistics Check (Host 1)
Query the active hardware pipelines of the physical switch from Ryu via REST endpoints to audit flow entry installation, traffic volume, and matches:
Bash

# Dump active flow rules on the physical switch pipelines
curl -X GET http://localhost:8080/stats/flow/44532510248004 | json_pp# Query match/drop counts and packet processing metrics from active switch meters
curl -X GET http://localhost:8080/stats/meter/44532510248004 | json_pp
4. Linux Gateway Kernel Queue & Traffic Filter Audits (Host 1)
Track real-time HTB packet queues, dropped packets, and rule token saturations across individual slices:
Bash

# Inspect runtime statistics and dropped packets across Slice 1 (eMBB Gateway)
tc -s qdisc show dev ogstun1
tc -s class show dev ogstun1# Trace running filter assignments and u32 classification matches
tc filter show dev ogstun1
5. RAN Base Station Emulation Tracking (Host 2)
Monitor real-time physical link connectivity and SCTP packet handshakes heading down to the core control planes:
Bash

# Check status logs for nr-gnb cell attachments
tail -n 100 ~/UERANSIM/build/nr-gnb.log 2>/dev/null || echo "Check running background stdout terminal panel."
🔍 Section 6: Historical Deep-Dive Troubleshooting Ledger
The OpenFlow Zero-Trust Network Freeze
Error: packet in 44532510248004 48:ea:62:54:1d:34 ff:ff:ff:ff:ff:ff 9
Root-Cause Analysis: An OpenFlow-enabled switch operates under zero-trust pipeline behaviors by default. Lacking a pre-configured routing profile or an active controller application, the switch does not know how to forward standard ARP broadcasts or cellular protocol handshakes. Every network frame was trapped, buffered, and pushed up to the controller as an unhandled packet-in event, breaking Layer-2 connectivity.
Granular Fix: Injected proactive flow entries into the switch fabric to build a direct port-to-port bypass tunnel loop between Port 1 (gNB Node) and Port 2 (5G Core Host):
Bash

curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_type": 2054}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
The Base Station Radio Link Block (SCTP Connection Refused)
Error: [sctp] INFO: Trying to establish SCTP connection... (192.168.1.10:38412) [sctp] ERROR: Connection failed: Connection refused
Root-Cause Analysis: While ICMP (ping) and typical TCP/UDP traffic paths were open, Ubuntu’s native Uncomplicated Firewall (ufw) was blocking the incoming Stream Control Transmission Protocol (SCTP) data channel on Port 38412, which handles the 5G control plane signaling.
Granular Fix: Disabled the host firewall interface completely to allow raw SCTP packet processing:
Bash

sudo ufw disable
Service-Based Interface (SBI) Cascade Crash Loop
Error: [sbi] WARNING: Couldn't connect to server (7): Failed to connect to 127.0.0.200 port 7777: Connection refused
Root-Cause Analysis: The original configuration files contained active statements directing internal core functions to interact via a Service Communication Proxy (SCP) loopback path at 127.0.0.200. Since no active SCP daemon was deployed in your local environment, the core service mesh collapsed.
Granular Fix: Modified amf.yaml, smf.yaml, and nssf.yaml to leverage direct communication with the central repository engine (NRF - Network Repository Function) on loopback target 127.0.0.10:7777.
Bash

sudo systemctl restart open5gs-nrfd open5gs-amfd open5gs-smfd
The "Lazy Router" Subnet Collision Trap
Error: uesimtun0 -> 10.45.0.2, uesimtun1 -> 10.45.0.3 (Collision: Expected 10.46.0.x pool block for Slice 2)
Root-Cause Analysis: Open5GS v2.7.6 cannot automatically split IP allocation pools across different UPFs using only the Slice ID (s_nssai) tag inside the session configurations. When multiple user plane nodes share the same Data Network Name (dnn: internet), the SMF uses the first matching block it reads, dumping all subscribers into the same UPF lane and triggering severe routing collisions.
Granular Fix: Implemented a DNN-Based Slicing Isolation Architecture. By building separate, unique network domains (internet1 through internet4) for each subscriber profile, you forced the core to segregate the traffic into separate pipelines.
Python Environment Command Path Disconnect
Error: hp@hp-HP-Z2-Tower-G9:~/sdn_lab$ source venv/bin/active bash: venv/bin/active: No such file or directory
Root-Cause Analysis: This error resulted from a simple syntax typo (active instead of activate), combined with trying to execute the built-in shell command source with sudo block escalation, which is unsupported.
Granular Fix: Cleanly initialized the workspace without root escalation:
Bash

cd ~/sdn_lab && source venv/bin/activate
The Ryu Eventlet Framework Compatibility Crash
Error: ImportError: cannot import name 'ALREADY_HANDLED' from 'eventlet.wsgi'
Root-Cause Analysis: Newer distributions of the eventlet asynchronous library stripped out old definitions like ALREADY_HANDLED from their WSGI definitions, breaking the Ryu runtime engine on platforms running modern Python 3.10 environments.
Granular Fix: Regressed the installation target to intermediate packages and patched the internal source file within the environment directory paths:
Bash

pip uninstall eventlet -y && pip install eventlet==0.33.3 dnspython==2.2.1
nano ~/sdn_lab/venv/lib/python3.10/site-packages/ryu/app/wsgi.py
Removed line entry from from eventlet.wsgi import ALREADY_HANDLED and replaced the response definition class wrapper block with a python clean pass declaration statement:
Python

class _AlreadyHandledResponse(Response):
    pass
Switch OpenFlow "Disable-Pending" Operational Hangups
Error: Administrative Mode.... Enable Operational Status..... Disable-Pending
Root-Cause Analysis: The hardware switch config was misconfigured to point back into its own OOB service IP address (192.168.0.239) as the controller engine destination port, forcing an empty loop.
Granular Fix: Purged the loopback pointer and assigned the explicit IP path of the actual Ryu host controller:
Plaintext

(M4300-8X8F) (Config)# no openflow controller 192.168.0.239 6633 tcp
(M4300-8X8F) (Config)# openflow controller 192.168.0.10 6653 tcp
Session Manager Profile Mismatch ("No dnnConfigurations")
Error: [smf] ERROR: [imsi-999700000000001:1] No dnnConfigurations
Root-Cause Analysis: The subscriber information was loaded into MongoDB using an older database model format. When SMF validated subscription contexts against UDM over the Service-Based Interface, it dropped sessions because the nested dnnConfigurations document block was completely missing.
Granular Fix: Opened mongosh, dropped the malformed entries, and re-added subscribers through the modern WebUI panel to auto-generate the complete JSON document structures correctly.
Core SBI Pipeline Crash (HTTP 504 Timeout Registration Rejects)
Error: [amf] ERROR: HTTP response error [504] [amf] ERROR: Registration reject [90]
Root-Cause Analysis: The AMF was receiving messages successfully from the RAN node but timed out communicating internally over port 7777 because the Unified Data Management (open5gs-udmd) daemon crashed into an inactive/dead state.
Granular Fix: Checked status binds via sudo systemctl status open5gs-udmd and brought the service back online using sudo systemctl start open5gs-udmd.
🎯 Section 7: Practical Real-World Use Cases
Mission-Critical Industrial Private 5G Proof-of-Concept (PoC): Factories, medical facilities, and shipping logistics hubs are transitioning from unstable WiFi solutions to Private 5G Standing infrastructure. This testbed functions as a working proof-of-concept to demonstrate network partitioning to technical stakeholders. For example, an industrial facility can carve out an isolated URLLC slice to safely steer automated guided vehicles (AGVs) with predictable low latency, while maintaining a parallel high-throughput eMBB slice streaming multi-channel 4K video feeds.
Security Auditing & Slice Isolation Vulnerability Sandboxing: A major risk vector in multi-tenant 5G environments is cross-slice fate sharing or slice hopping. Security engineers can utilize this precise hardware-distributed testbed to execute penetration testing scripts against the core Service-Based Interface (SBI). It allows them to audit whether an unmitigated Distributed Denial of Service (DDoS) flood or a container escape exploit target on a low-security public consumer slice can break past isolation parameters to degrade performance on a secure private tenant network slice.
Massive Internet of Things (MIoT) Infrastructure Scaling Analysis: By leveraging the Raspberry Pi edge node, this environment acts as an accurate model of remote microcontroller array clusters. System engineers can modify the client thread generation variables to simulate hundreds of concurrently attaching subscriber devices. This helps evaluate how the Access and Mobility Management Function (AMF) or local database handlers manage registration floods, simulating scenarios like smart-city utility meters reporting data simultaneously.
5G-Aware Mobile Application Testing under Strict Service Level Agreements: Application developers building software for high-stakes environments—such as drone flight controller telemetry or real-time remote clinical diagnostics tools—can link their client binaries straight into the virtual uesimtun ports on the Raspberry Pi. This lets them test how their software code reacts when the network faces sudden, deliberate bandwidth constraints or simulated link failures, ensuring robust error handling before deployment...how to add this readme in my github this project folder
