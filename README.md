# Team_1
Containerized Multi-Tier Network Service with Performance Analysis

This project is a fully containerized 3-tier application consisting of:

* Frontend (Nginx static site)
* Backend (Node.js API)
* Database (PostgreSQL)
* Automated Tester Container
* Custom Docker network with static IPs
* Traffic capture (PCAP) using tcpdump
* Deployment + Testing Automation Script

The full stack runs using Docker & Docker Compose, with automated build, deploy, health checks, and network latency testing.

Project Overview

This project demonstrates:

✔ Full-stack microservice architecture
✔ Custom Docker bridge network (team_1_app_net)
✔ Static IP allocation for predictable service communication
✔ Automated deployment using deploy_and_test.sh
✔ Health checks for all services
✔ End-to-end connectivity testing using ping from tester container
✔ Packet capture using tcpdump → saved as .pcap for Wireshark
✔ Logging, resource monitoring, and capture artifacts stored in /captures


⚙️ Prerequisites

Make sure you have:

Docker
Docker Compose
Wireshark (optional, for opening .pcap files)

🧱 Running the Project:
1. Clone the repo
2. Run the Deployment Script
  This script:
  * Removes old containers/networks
  * Rebuilds all services
  * Creates custom Docker network (172.10.0.0/16)
  * Starts all services  
  * Waits for health checks
  * Runs network tests
  * Captures traffic to .pcap file

📡 Network Testing

The script performs:

✔ Ping tests from tester → frontend/backend/db
✔ Latency measurement
✔ Network interface detection
✔ tcpdump capture on Docker bridge
