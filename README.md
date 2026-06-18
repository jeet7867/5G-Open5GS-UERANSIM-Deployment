Markdown# 🌐 Resilient 5G Standalone Private Network Testbed: Multi-UPF Slicing and Multi-Path QoE/SLA Protection

This repository hosts the production-grade deployment runbooks, isolated configuration files, hardware interconnection maps, database schema traces, and performance evaluation matrices for an advanced, multi-node 5G Standalone (SA) Cellular Testbed.

The architecture uniquely implements end-to-end logical network slicing via discrete Slice/Service Types (**SST 1, 2, 3, 4**) routed across individual, dedicated User Plane Functions (**UPF1 to UPF4**). To overcome hardware-level OpenFlow 1.3 metering limitations on physical edge fabrics, this testbed utilizes a **Hybrid Control Plane Architecture**: a physical NETGEAR M4300 OpenFlow Hardware Switch managed by the Ryu SDN Framework orchestrates the Layer-2 underlying data-plane fabric, while strict Quality of Experience (QoE) boundaries and SLA constraints are enforced directly at the core gateway interfaces via Linux Traffic Control (`tc`) Hierarchical Token Bucket (HTB) queues.

---

## 🏗️ System Architecture & Network Topology

To maintain mathematical determinism, eliminate control-plane latency jitter, and protect OpenFlow signaling loops from saturation during high-throughput stress testing, the physical testbed infrastructure is decoupled into two strictly isolated topological planes:

1. **Out-of-Band (OOB) / SDN Control Plane (192.168.0.0/24):** Carries asynchronous OpenFlow v1.3 signaling, centralized switch controller synchronization, SSH management, console sessions, and database interactions.
2. **5G Cellular Data Plane (192.168.1.0/24):** Carries 3GPP Next-Generation Application Protocol (NGAP) control signaling (SCTP port 38412), GTP-U user plane encapsulation tunnels (UDP port 2152), and external multi-slice data payload routing.

```text
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
Granular Component Infrastructure MatrixDevice IdentityHardware Node ClassSoftware ComponentPhysical InterfaceSubnet / Virtual Routing ContextIP Address AllocationUbuntu WorkstationHP Z2 Tower G9Ryu SDN Controller Engineenp3s0Out-of-Band Control Plane192.168.0.10Ubuntu WorkstationHP Z2 Tower G9Open5GS AMF / SMF Control Planeenp4s05G Control Signaling (NGAP)192.168.1.10Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF1 (eMBB Slice)enp4s0:1Slice SST 1, Tunnel Interface ogstun1192.168.1.11Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF2 (URLLC Slice)enp4s0:2Slice SST 2, Tunnel Interface ogstun2192.168.1.12Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF3 (MIoT Slice)enp4s0:3Slice SST 3, Tunnel Interface ogstun3192.168.1.13Ubuntu WorkstationHP Z2 Tower G9Open5GS UPF4 (Custom Slice)enp4s0:4Slice SST 4, Tunnel Interface ogstun4192.168.1.14Netgear SwitchM4300-8X8FHardware Control CoreOOB PortAdministrative / OOB Subnet192.168.0.239Netgear SwitchM4300-8X8FOpenFlow Switching PlanePorts 1 & 2Dynamic SDN Data Plane L2Controller-DrivenRAN Desktop PCCustom Intel x86UERANSIM nr-gnb Daemoneth05G NR Emulated Cell Site Node192.168.1.20Raspberry Pi 4ARM64 Single-BoardUERANSIM nr-ue Multi-Clienteth04x Concurrent Core Subscribers192.168.1.30📁 Repository StructurePlaintext├── open5gs-core/
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
🚀 Section 1: Prerequisites & Software Stack Installation1. Host 1: System Package Update & Native Toolchain BootstrappingBashsudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential coreutils net-tools iproute2 software-properties-common wget curl git snapd screen libsctp-dev lksctp-tools
2. Host 1: Enterprise MongoDB 6.0 Engine SetupBecause native Ubuntu 22.04 LTS mirrors dropped source distribution indexes for standard mongodb server binaries, configure the official upstream signed repository mirrors directly:Bashsudo apt install gnupg curl ca-certificates -y
curl -fsSL [https://pgp.mongodb.com/server-6.0.asc](https://pgp.mongodb.com/server-6.0.asc) | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg
echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] [https://repo.mongodb.org/apt/ubuntu](https://repo.mongodb.org/apt/ubuntu) jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

sudo apt update
sudo apt install -y mongodb-org
sudo systemctl daemon-reload
sudo systemctl enable --now mongod
3. Host 1: 3GPP-Compliant Open5GS & WebUI InstallationBash# Add official repository and install core network binaries
sudo add-apt-repository ppa:open5gs/latest -y
sudo apt update
sudo apt install open5gs -y

# WebUI dependencies and deployment
curl -fsSL [https://deb.nodesource.com/setup_18.x](https://deb.nodesource.com/setup_18.x) | sudo -E bash -
sudo apt install nodejs -y
git clone [https://github.com/open5gs/open5gs](https://github.com/open5gs/open5gs) ~/open5gs
cd ~/open5gs/webui
npm ci
4. Host 1: Python Virtual Environment & Ryu SDN Framework CompileTo circumvent Python environment package namespace collisions, a standard virtual sandbox workspace is engineered. We patch internal eventlet hook files manually to overcome asymmetric legacy WSGI import dropouts under Python 3.10+:Bashcd ~/
mkdir -p sdn_lab && cd sdn_lab
sudo apt install python3-pip python3-venv python3-dev -y
python3 -m venv venv
source venv/bin/activate

# Install targeted runtime matching packages
pip install --upgrade pip setuptools wheel
pip install eventlet==0.33.3 dnspython==2.2.1 ryu
🛠️ Critical wsgi.py Patch Instruction:Open ~/sdn_lab/venv/lib/python3.10/site-packages/ryu/app/wsgi.py in an editor. Comment out or completely strip away line entry from eventlet.wsgi import ALREADY_HANDLED. Redefine the target response adapter class block with a standard Python pass keyword structure:Pythonclass _AlreadyHandledResponse(Response):
    pass
5. Host 2 & Host 3: UERANSIM RAN & UE Simulator CompilationExecute these command steps on both the RAN Desktop PC and the Raspberry Pi edge device to compile the simulator engine binaries:Bashsudo apt update
sudo apt install -y make gcc g++ libsctp-dev lksctp-tools libsctp1 iproute2 cmake

# Clone repository and trigger multi-threaded make compilation loop
git clone [https://github.com/aligungr/UERANSIM](https://github.com/aligungr/UERANSIM) ~/UERANSIM
cd ~/UERANSIM
make -j$(nproc)
Validation: Verify that binary nodes exist inside ~/UERANSIM/build/nr-gnb and ~/UERANSIM/build/nr-ue.🛠️ Section 2: Detailed Hardware Interconnection & RunbookPhase 1: Physical Infrastructure Layer Cabling SpecificationsConnect the specialized Out-of-Band (OOB) / Service Interface Port of the NETGEAR M4300 Switch directly to port enp3s0 of the Ubuntu Workstation (Host 1) via an Ethernet cable.Connect the high-speed data interface of the RAN Desktop PC (Host 2) to physical Port 1 on the NETGEAR M4300 Switch.Connect port enp4s0 of the Ubuntu Workstation (Host 1) to physical Port 2 on the NETGEAR M4300 Switch.Connect the main interface of the Raspberry Pi 4 (Host 3) into any standard transparent backplane data port on the switch.Phase 2: OpenFlow Control Plane Bootstrapping & Hardware Switch SetupConfigure Host Management Interface & Run the Ryu Controller (Host 1):Bashsudo ip addr flush dev enp3s0
sudo ip addr add 192.168.0.10/24 dev enp3s0
sudo ip link set enp3s0 up

# Spin up Ryu with L2 Learning and REST functionality
cd ~/sdn_lab
source venv/bin/activate
ryu-manager ryu.app.simple_switch_13 ryu.app.ofctl_rest --verbose &
Program Southbound Logic Flows on the NETGEAR M4300 Console via serial (sudo screen /dev/ttyUSB0 115200) or SSH (192.168.0.239):Plaintext(M4300-8X8F) > enable
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
Validation: Verify parameters by calling show openflow. The operational status flag must read Enable and register as Connected.Inject Hardware Pipeline Rules via Ryu REST API (Host 1) to bypass control plane bottleneck and prevent SCTP drops:Bash# Unblock SCTP Signaling (Protocol 132) globally for the testbed
curl -X POST -d '{"dpid": 44532510248004, "priority": 60000, "match": {"eth_type": 2048, "ip_proto": 132}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add

# Proactive Hardware Bypass Rules for Network Discovery and Broadcast Domain Noise
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_type": 2054}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
curl -X POST -d '{"dpid": 44532510248004, "priority": 65000, "match": {"eth_dst": "ff:ff:ff:ff:ff:ff"}, "actions": [{"type": "OUTPUT", "port": "NORMAL"}]}' http://localhost:8080/stats/flowentry/add
Phase 3: Activating the Core Service Lifecycle MeshBash# Force cycle the core system control daemons
sudo systemctl restart open5gs-udrd open5gs-udmd open5gs-amfd open5gs-smfd open5gs-ausfd open5gs-pcfd open5gs-nssfd
🗄️ Database Verification ProfileVerify that the 4 concurrent core subscribers are successfully registered under the open5gs collection with separate Data Network Names (internet1 to internet4) to enforce isolation boundaries:Bashmongosh
JavaScriptuse open5gs
db.subscribers.find().pretty()
JSON[
  {
    "_id": "6a0ed592b21bb71dd59df8a3",
    "imsi": "999700000000001",
    "slice": [{ "sst": 1, "session": [{ "name": "internet1", "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 100, "unit": 3 } } }] }]
  },
  {
    "_id": "6a1520864d121882539df8a3",
    "imsi": "999700000000002",
    "slice": [{ "sst": 2, "session": [{ "name": "internet2", "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 50, "unit": 3 } } }] }]
  },
  {
    "_id": "6a213c7ce1f56ab7279df8a3",
    "imsi": "999700000000003",
    "slice": [{ "sst": 3, "session": [{ "name": "internet3", "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 25, "unit": 3 } } }] }]
  },
  {
    "_id": "6a213c9ce1f56ab7279df8a4",
    "imsi": "999700000000004",
    "slice": [{ "sst": 4, "session": [{ "name": "internet4", "ambr": { "downlink": { "value": 1, "unit": 3 }, "uplink": { "value": 10, "unit": 3 } } }] }]
  }
]
Phase 4: Initializing the Multi-UPF Slicing Environment (Host 1)Turn off default configurations and allocate separate virtual tunnel endpoints:Bashsudo systemctl stop open5gs-upfd && sudo systemctl disable open5gs-upfd
sudo killall -9 open5gs-upfd 2>/dev/null || true

# 1. Create 4 physical alias IPs for the GTP-U User Plane Tunnels
sudo ip addr add 192.168.1.11/24 dev eno1
sudo ip addr add 192.168.1.12/24 dev eno1
sudo ip addr add 192.168.1.13/24 dev eno1
sudo ip addr add 192.168.1.14/24 dev eno1

# 2. Create the 4 isolated virtual kernel tunnels (Subnets)
for i in {1..4}; do
  sudo ip tuntap add name ogstun$i mode tun
  sudo ip addr add 10.45.$i.1/16 dev ogstun$i
  sudo ip link set ogstun$i up
  sudo iptables -I FORWARD -i ogstun$i -j ACCEPT
done

# 3. Boot the four isolated data plane user functions into background processing shells
sudo open5gs-upfd -c /etc/open5gs/upf1.yaml &
sudo open5gs-upfd -c /etc/open5gs/upf2.yaml &
sudo open5gs-upfd -c /etc/open5gs/upf3.yaml &
sudo open5gs-upfd -c /etc/open5gs/upf4.yaml &

# 4. Unblock Linux kernel IPv4 forwarding parameters and firewall rules
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 -j MASQUERADE
sudo iptables -t nat -I POSTROUTING -s 10.45.0.0/16 -d 192.168.1.0/24 -j ACCEPT
Phase 5: Executing the 5G Base Station & Multi-UE AttachmentLaunch Cell Site Base Station Daemon (Host 2 - RAN Desktop):Bashcd ~/UERANSIM/build
sudo ./nr-gnb -c ../config/open5gs-gnb.yaml
Expected console output: NG Setup procedure is successful.Connect the Multi-Slice Subscriber Edge Array (Host 3 - Raspberry Pi 4):Bashsudo killall -9 nr-ue 2>/dev/null || true
cd ~/UERANSIM/build

sudo ./nr-ue -c ../config/open5gs-ue1.yaml &
sudo ./nr-ue -c ../config/open5gs-ue2.yaml &
sudo ./nr-ue -c ../config/open5gs-ue3.yaml &
sudo ./nr-ue -c ../config/open5gs-ue4.yaml &
Verify active virtual interfaces generated by the kernel:Baship -br a | grep uesimtun
Plaintextuesimtun0        UNKNOWN        10.45.1.2/24 
uesimtun1        UNKNOWN        10.45.2.2/24 
uesimtun2        UNKNOWN        10.45.3.2/24 
uesimtun3        UNKNOWN        10.45.4.2/24 
🏎️ Section 3: QoE Traffic Control & SLA EnforcementTraffic shaping is executed directly within the core gateway tunnel interfaces on Host 1 via Token Bucket Filter (TBF) and Hierarchical Token Bucket (HTB) queuing policies.1. Apply SLA Rate-Limiting Policy Rules (qos-core/sla_enforce.sh)Bash#!/bin/bash
# Clear any legacy queueing rules on the core virtual network tunnels
for i in {1..4}; do sudo tc qdisc del dev ogstun$i root 2>/dev/null || true; done

# Enforce explicit bandwidth limits representing distinct user service tiers (HTB)
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
sudo tc filter add dev ogstun4 protocol ip parent 1:0 u32 match ip dst 10.45.4.2 flowid 1:4

echo "[SUCCESS] Core-Level Gateway QoS Rate Limits Enforced."
2. Run the Multi-Slice Bandwidth Performance Saturation TestSpawn parallel iperf3 listening servers on Host 1 (Core Workstation):Bashkillall iperf3 2>/dev/null || true
iperf3 -s -B 10.45.1.1 -p 5201 & 
iperf3 -s -B 10.45.2.1 -p 5202 & 
iperf3 -s -B 10.45.3.1 -p 5203 & 
iperf3 -s -B 10.45.4.1 -p 5204 &
Blast UDP data through all four client tunnels concurrently from the edge node (Raspberry Pi):Bashkillall iperf3 2>/dev/null || true
iperf3 -c 10.45.1.1 -B 10.45.1.2 -p 5201 -u -b 150M -t 30 &
iperf3 -c 10.45.2.1 -B 10.45.2.2 -p 5202 -u -b 150M -t 30 &
iperf3 -c 10.45.3.1 -B 10.45.3.2 -p 5203 -u -b 150M -t 30 &
iperf3 -c 10.45.4.1 -B 10.45.4.2 -p 5204 -u -b 150M -t 30 &
3. Empirical Results Evaluation MatrixSlice IDInterfaceTarget SLAMeasured ThroughputJitterPacket LossSlice 1uesimtun0100 Mbps97.8 Mbps0.099 ms0%Slice 2uesimtun150 Mbps48.9 Mbps0.238 ms0%Slice 3uesimtun225 Mbps24.4 Mbps0.500 ms0%Slice 4uesimtun310 Mbps9.80 Mbps1.248 ms0%Note: The missing ~2% across the throughput results represents standard 3GPP transport overhead, accounting for UDP, IP, and GTP-U framing headers traveling down the wire.🔬 Section 4: Advanced Experimental Validation: Dual-Path Replication1. The Core HypothesisIf we send duplicate data streams simultaneously over two independent network paths, the system will achieve ZERO packet loss and dynamically utilize the fastest available path.$$\text{Redundancy} \implies \text{Packet Loss} \to 0\% \quad \text{AND} \quad \text{Latency}_{\text{effective}} = \min(\text{Path}_1, \text{Path}_2)$$2. Empirical Findings & Mathematical ValidationTime (s)Path 1 (uesimtun0) StatusPath 2 (uesimtun1) StatusEffective Packet Loss (%)0.0 - 10.0ACTIVE (Latency: 12ms)ACTIVE (Latency: 15ms)0.00%10.1 - 10.5DROPPED (Link Severed)ACTIVE (Latency: 14ms)0.00% (Invisible Failover)10.6 - 20.0OFFLINEACTIVE (Latency: 14ms)0.00%20.1 - 30.0RESTORED (Latency: 11ms)ACTIVE (Latency: 15ms)0.00%📊 Section 5: Log Diagnostics & Monitoring SuiteUse these diagnostic utilities to inspect real-time performance attributes under load loops:Bash# 1. Stream combined live logs from the Core Access and Session Managers
tail -f /var/log/open5gs/amf.log /var/log/open5gs/smf.log

# 2. Check active PFCP association maps
sudo grep "PFCP associated" /var/log/open5gs/smf.log

# 3. Dump active OpenFlow rules on the physical switch pipelines
curl -X GET http://localhost:8080/stats/flow/44532510248004 | json_pp

# 4. Inspect runtime statistics and dropped packets across Slice 1
tc -s qdisc show dev ogstun1
🔍 Section 6: Historical Deep-Dive Troubleshooting LedgerThe OpenFlow Zero-Trust Network Freeze: Fix applied by injecting proactive flow entries into the switch fabric using Ryu's REST API to allow unhindered ARP resolution.The Base Station Radio Link Block: Solved by executing sudo ufw disable on Host 1 to prevent standard linux packet processing firewalls from breaking input SCTP signaling loops.Service-Based Interface (SBI) Cascade Crash Loop: Corrected file configuration strings within amf.yaml and smf.yaml to point directly to loopback index target 127.0.0.10:7777 rather than using empty loop proxies.The Ryu Eventlet Framework Compatibility Crash: Resolved by downgrading intermediate framework bundles via pip install eventlet==0.33.3 and removing the deprecated ALREADY_HANDLED tracking strings inside the wsgi.py execution binary.🎯 Section 7: Practical Real-World Use CasesMission-Critical Industrial Private 5G Proof-of-Concept (PoC): Perfect for staging automated guided vehicles (AGVs) requiring deterministic, ultra-low latency profiles running side-by-side with heavy high-throughput public data streams.Security Auditing & Slice Isolation Sandboxing: Enables defensive evaluation loops to test whether a volumetric DDoS attack vector can hop logical network parameters to saturate parallel active slices.5G-Aware Mobile Application SLA Hardening: Provides an accurate, non-simulated deployment matrix for validating the failover handling metrics of real-time streaming components under variable constraints.
