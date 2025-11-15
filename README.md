# Team_1
Containerized Multi-Tier Network Service with Performance Analysis

# Three-Tier Dockerized Application

## Overview

This project implements a **three-tier architecture** using Docker containers:

1. **Frontend**: Web server serving static content (Nginx in Alpine).
2. **Backend**: API service (Node.js) handling application logic.
3. **Database**: PostgreSQL storing persistent data.


## Directory Structure

Team_1/
├── frontend/          # Frontend Dockerfile and static files
├── backend/           # Backend Dockerfile and Node.js app
├── db/                # Database Dockerfile and initialization scripts
├── deploy_and_test.sh # Automated deployment & test script
├── docker-compose.yml # Compose file defining multi-tier services
├── captures/          # Folder to store tcpdump PCAP files
└── README.md


## Prerequisites

* Ubuntu VM / Linux host
* **Docker** (v20+) & **Docker Compose** (v2+)
* **Wireshark / tshark** (for network analysis)
* **Git** (for version control)
* **VSCode** (for editing Dockerfiles and scripts)


Install Docker & Docker Compose on Ubuntu:

sudo apt update
sudo apt install docker.io docker-compose -y
sudo systemctl enable --now docker






