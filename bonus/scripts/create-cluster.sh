#!/usr/bin/env bash
set -euo pipefail

cluster=iot
command -v docker >/dev/null
command -v k3d >/dev/null
command -v kubectl >/dev/null

if ! k3d cluster list -o json | grep -Eq '"name"[[:space:]]*:[[:space:]]*"iot"'; then
    k3d cluster create "$cluster" --agents 1 -p "8888:30088@server:0"
fi
kubectl config use-context "k3d-$cluster"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Available deployment --all \
    -n argocd --timeout=900s

sudo tee /etc/systemd/system/iot-argocd-port-forward.service >/dev/null <<'UNIT'
[Unit]
Description=Forward Argo CD UI from the parent VM to its host
After=network-online.target

[Service]
Type=simple
User=vagrant
Group=vagrant
Environment=KUBECONFIG=/home/vagrant/.kube/config
ExecStart=/usr/local/bin/kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8080:443
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now iot-argocd-port-forward.service

echo "K3d cluster '$cluster' and Argo CD are ready."
