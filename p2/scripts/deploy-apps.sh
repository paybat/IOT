#!/usr/bin/env bash
set -euo pipefail
kubectl() { sudo k3s kubectl "$@"; }
kubectl apply -f /vagrant/confs/
for app in app1 app2 app3; do
  kubectl rollout status "deployment/${app}" --timeout=180s
done
# K3s installs Traefik asynchronously through its packaged Helm chart. The
# API can be ready before the Traefik Deployment has been created.
for attempt in $(seq 1 60); do
  if kubectl get deployment traefik -n kube-system >/dev/null 2>&1; then
    break
  fi
  sleep 3
done
kubectl rollout status deployment/traefik -n kube-system --timeout=180s
kubectl wait --for=condition=Ready pod -n kube-system \
  -l svccontroller.k3s.cattle.io/svcname=traefik --timeout=180s
kubectl get deployments,pods,services,ingress -o wide
