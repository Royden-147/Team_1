#!/usr/bin/env bash
set -euo pipefail

# Config
COMPOSE_FILE="docker-compose.yml"
NETWORK_NAME="app_net"
SUBNET="172.20.0.0/16"
PCAP_OUT="./captures"
PCAP_FILE="$PCAP_OUT/app_net_capture.pcap"
REPORT_DIR="./reports"
REPORT_CSV="$REPORT_DIR/latency_results.csv"
TIMEOUT=60  # seconds to wait for healthchecks

mkdir -p "$PCAP_OUT" "$REPORT_DIR"

# 1) Ensure Docker network exists with required subnet (idempotent)
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Network $NETWORK_NAME exists, verifying subnet..."
  CURRENT_SUBNET=$(docker network inspect -f '{{ range .IPAM.Config }}{{ .Subnet }}{{ end }}' "$NETWORK_NAME")
  if [ "$CURRENT_SUBNET" != "$SUBNET" ]; then
    echo "Network $NETWORK_NAME exists but subnet is $CURRENT_SUBNET (expected $SUBNET). Recreating..."
    docker network rm "$NETWORK_NAME"
    docker network create --driver bridge --subnet "$SUBNET" --gateway 172.20.0.1 "$NETWORK_NAME"
  fi
else
  echo "Creating network $NETWORK_NAME with subnet $SUBNET"
  docker network create --driver bridge --subnet "$SUBNET" --gateway 172.20.0.1 "$NETWORK_NAME"
fi

# 2) Tear down previous stack (idempotent) and bring up new
echo "Bringing down any existing compose stack (if present)..."
docker compose down --volumes --remove-orphans || true

echo "Bringing up the stack..."
docker compose up --build -d

# 3) Wait for containers to become healthy (or up)
echo "Waiting up to $TIMEOUT seconds for services to be healthy..."
end=$((SECONDS + TIMEOUT))
while [ $SECONDS -lt $end ]; do
  ok=true
  for svc in frontend backend db; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null || echo "nohealth")
    if [ "$status" != "healthy" ]; then
      ok=false
      break
    fi
  done
  if $ok; then
    echo "All services healthy."
    break
  fi
  sleep 2
done

if ! $ok; then
  echo "Warning: Not all services reported healthy within timeout. Continuing tests anyway."
fi

# 4) Start a tcpdump capture on the bridge interface corresponding to our network
BRIDGE_NAME=$(docker network inspect -f '{{ index .Options "com.docker.network.bridge.name" }}' "$NETWORK_NAME" 2>/dev/null || echo "")
if [ -z "$BRIDGE_NAME" ]; then
  # fallback: find bridge by substring of network ID
  NETID=$(docker network inspect -f '{{.Id}}' "$NETWORK_NAME")
  BRIDGE_NAME="br-${NETID:0:12}"
fi
echo "Bridge interface detected: $BRIDGE_NAME"

# must run as root or with sudo for tcpdump
if ! command -v tcpdump >/dev/null 2>&1; then
  echo "tcpdump not installed on host. Please install tcpdump to capture traffic."
else
  echo "Starting tcpdump (background) to capture traffic on $BRIDGE_NAME -> $PCAP_FILE"
  sudo pkill -f "tcpdump -i $BRIDGE_NAME" || true
  sudo tcpdump -i "$BRIDGE_NAME" -w "$PCAP_FILE" not icmp6 &
  TCPDUMP_PID=$!
  echo "tcpdump PID: $TCPDUMP_PID"
fi

# 5) Collect resource usage snapshot (docker stats) for 10 seconds (sample)
echo "Collecting resource usage snapshot..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" > "$REPORT_DIR/docker_stats_snapshot.txt" || true

# 6) From tester container, run tests: ping, curl latency, ssh tests
echo "Running functional & latency tests from tester container..."

# helper: run command inside tester
dexec() { docker exec tester sh -c "$*"; }

# measure latency between tiers:
# result CSV header: test,source,target,method,latency_seconds
echo "test,source,target,method,latency_seconds" > "$REPORT_CSV"

# ping backend from tester
for target in 172.20.0.20 172.20.0.30 172.20.0.40; do
  echo "ping -c 4 $target from tester"
  PING_MS=$(dexec "ping -c 4 -w 6 $target | awk -F'/' 'END{ if(NF>4) print \$(5)/1000; else print \"NA\" }'")
  echo "ping_tester,$(docker inspect -f '{{.Name}}' tester | sed 's#^/##'),$target,ping,$PING_MS" >> "$REPORT_CSV"
done

# HTTP curl latency to backend from tester
for i in 1 2 3; do
  LAT=$(dexec "time sh -c 'wget -qO- http://172.20.0.30:3000/health' 2>&1 | awk '/real/ {print \$2}' || echo NA")
  # convert mm:ss or s.ms to seconds (if in format 0m0.234s or 0.234s)
  # best-effort parsing:
  if echo "$LAT" | grep -q 'm'; then
    SEC=$(echo "$LAT" | sed -E 's/([0-9]+)m([0-9\.]+)s/\\1*60+\\2/' | bc -l)
  else
    SEC=$(echo "$LAT" | sed -E 's/s$//' )
  fi
  echo "http_latency,tester,backend,http,$SEC" >> "$REPORT_CSV"
done

# SSH validation: try ssh from tester to frontend and backend using sshpass (we installed sshpass on tester image? no)
# We'll use ssh with password via sshpass installed on tester (script expects sshpass present; if not, attempt with expect fallback)
dexec "apk add --no-cache sshpass >/dev/null 2>&1 || true"

for targetHost in 172.20.0.20 172.20.0.30 172.20.0.40; do
  echo "Testing SSH connectivity from tester -> $targetHost"
  # try password-based ssh
  SSH_OUT=$(dexec "sshpass -p devpass ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 dev@${targetHost} 'echo SSH_OK' 2>&1" || true)
  if echo "$SSH_OUT" | grep -q SSH_OK; then
    echo "ssh_ok,tester,$targetHost,ssh,0" >> "$REPORT_CSV"
    echo "SSH OK to $targetHost"
  else
    echo "ssh_fail,tester,$targetHost,ssh,NA" >> "$REPORT_CSV"
    echo "SSH FAIL to $targetHost (output: $SSH_OUT)"
  fi
done

# 7) collect tcp retransmissions & protocol breakdown via tshark (if available)
if ! command -v tshark >/dev/null 2>&1; then
  echo "tshark not installed on host. Skipping automated tshark analysis. You can open $PCAP_FILE in Wireshark for analysis."
else
  # give tcpdump a few more seconds, then stop
  sleep 5
  if [ -n "${TCPDUMP_PID-}" ]; then
    sudo kill "$TCPDUMP_PID" || true
    sleep 1
  fi

  echo "Running tshark summary..."
  # protocol breakdown
  tshark -r "$PCAP_FILE" -q -z io,phs > "$REPORT_DIR/tshark_protocol_breakdown.txt" || true

  # count tcp retransmissions
  tshark -r "$PCAP_FILE" -Y "tcp.analysis.retransmission" -q -z io,stat,0,"COUNT(tcp.analysis.retransmission)frame" > "$REPORT_DIR/tshark_retransmissions.txt" || true

  # compute basic RTTs from TCP handshake (SYN->SYN+ACK) (tshark can compute tcp.analysis.ack_rtt)
  tshark -r "$PCAP_FILE" -Y "tcp.analysis.ack_rtt" -T fields -e frame.time_epoch -e tcp.analysis.ack_rtt > "$REPORT_DIR/tshark_rtts.txt" || true

  # summary:
  echo "PCAP saved to $PCAP_FILE"
fi

# 8) Docker stats live snapshot for 10 seconds (sampling via top)
echo "Collecting time-series resource usage (10s sample)..."
docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" > "$REPORT_DIR/docker_stats_final.txt" || true

# 9) Produce a simple human-readable report stub
cat > "$REPORT_DIR/summary_report.txt" <<EOF
Deployment report - $(date)
Project: three-tier containerized architecture
Network: $NETWORK_NAME ($SUBNET)
PCAP: $PCAP_FILE
Results CSV: $REPORT_CSV

Notes:
- See tshark outputs (if available) in $REPORT_DIR
- Docker stats snapshots: $REPORT_DIR/docker_stats_snapshot.txt and docker_stats_final.txt
- For deeper packet analysis open $PCAP_FILE in Wireshark and run:
  - Statistics -> Protocol Hierarchy
  - Statistics -> Conversations
  - Use display filters: tcp.analysis.retransmission, tcp.analysis.rtt, icmp

EOF

echo "Done. Reports and captures in $REPORT_DIR and $PCAP_OUT."
echo "Open $PCAP_FILE in Wireshark on the host VM for interactive analysis."

# exit successfully
