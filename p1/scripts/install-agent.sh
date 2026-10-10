#!/usr/bin/env bash
set -euo pipefail
echo "Waiting for the K3s server at ${K3S_SERVER_IP}:6443"
apt-get update
apt-get install -y ca-certificates curl
server_ready=false
for attempt in $(seq 1 60); do
  if curl -kfsS "https://${K3S_SERVER_IP}:6443/ping" >/dev/null 2>&1; then server_ready=true; break; fi
  sleep 2
done
if [ "$server_ready" != true ]; then
  echo "K3s server at ${K3S_SERVER_IP}:6443 did not respond within 120 seconds" >&2
  exit 1
fi
curl -sfL https://get.k3s.io | K3S_URL="https://${K3S_SERVER_IP}:6443" K3S_TOKEN="${K3S_TOKEN}" K3S_NODE_NAME="${K3S_NODE_NAME}" INSTALL_K3S_EXEC="agent --node-ip ${K3S_NODE_IP}" sh -
sudo systemctl is-active --quiet k3s-agent
echo "Agent joined; verify from the server with: sudo k3s kubectl get nodes -o wide"
