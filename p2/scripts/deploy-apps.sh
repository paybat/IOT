#!/usr/bin/env bash
set -euo pipefail
kubectl() { sudo k3s kubectl "$@"; }
kubectl apply -f /vagrant/confs/
for app in app1 app2 app3; do
  kubectl rollout status "deployment/${app}" --timeout=180s
done
kubectl rollout status deployment/traefik -n kube-system --timeout=180s
kubectl wait --for=condition=Ready pod -n kube-system \
  -l svccontroller.k3s.cattle.io/svcname=traefik --timeout=180s
kubectl get deployments,pods,services,ingress -o wide
