#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../confs/gitlab"

command -v kubectl >/dev/null
kubectl get nodes >/dev/null

if ! kubectl get secret gitlab-root -n gitlab >/dev/null 2>&1; then
    password="$(openssl rand -base64 24 | tr -d '\n')"
    kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic gitlab-root -n gitlab --from-literal="password=$password"
else
    kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
fi

kubectl apply -f "$MANIFEST_DIR/namespace.yaml"
kubectl apply -f "$MANIFEST_DIR/gitlab.yaml"
kubectl rollout status statefulset/gitlab -n gitlab --timeout=3600s

sudo tee /etc/systemd/system/iot-gitlab-port-forward.service >/dev/null <<'UNIT'
[Unit]
Description=Forward GitLab UI from the parent VM to its host
After=network-online.target

[Service]
Type=simple
User=vagrant
Group=vagrant
Environment=KUBECONFIG=/home/vagrant/.kube/config
ExecStart=/usr/local/bin/kubectl port-forward --address 0.0.0.0 -n gitlab svc/gitlab 8081:80
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now iot-gitlab-port-forward.service

echo "GitLab: http://localhost:8081/ (username: root)"
echo 'Root password: kubectl get secret gitlab-root -n gitlab -o jsonpath="{.data.password}" | base64 -d'
