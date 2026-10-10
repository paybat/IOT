#!/usr/bin/env bash
set -euo pipefail
echo "Installing the K3s server on $(hostname)"
apt-get update
apt-get install -y ca-certificates curl
curl -sfL https://get.k3s.io | K3S_TOKEN="${K3S_TOKEN}" K3S_NODE_NAME="${K3S_NODE_NAME}" INSTALL_K3S_EXEC="server --node-ip ${K3S_NODE_IP} --write-kubeconfig-mode 644" sh -
ready=false
for attempt in $(seq 1 60); do
  if k3s kubectl get --raw=/readyz >/dev/null 2>&1; then ready=true; break; fi
  sleep 2
done
if [ "$ready" != true ]; then
  echo "K3s server did not become ready within 120 seconds" >&2
  exit 1
fi
k3s kubectl get nodes
