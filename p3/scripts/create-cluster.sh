#!/usr/bin/env bash
set -e

CLUSTER=iot
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_URL="${GIT_REPO_URL:-$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)}"

if [ -z "$REPO_URL" ]; then
    echo "Set GIT_REPO_URL or configure a GitHub origin remote." >&2
    exit 1
fi
case "$REPO_URL" in
    https://github.com/*) ;;
    *) echo "Argo CD needs a public HTTPS GitHub URL; got: $REPO_URL" >&2; exit 1 ;;
esac

# Check required tools and the public repository
command -v docker >/dev/null
command -v k3d >/dev/null
command -v kubectl >/dev/null
git ls-remote "$REPO_URL" HEAD >/dev/null

# Create cluster
if ! k3d cluster list -o json | grep -Eq '"name"[[:space:]]*:[[:space:]]*"iot"'; then
    k3d cluster create "$CLUSTER" --agents 1 -p "8888:30088@server:0"
fi
kubectl config use-context "k3d-$CLUSTER"

# Install Argo CD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Available deployment --all \
    -n argocd --timeout=900s

# Deploy app and wait for Argo CD to sync it before checking its namespace
sed "s|__GIT_REPO_URL__|$REPO_URL|g" \
    "$REPO_ROOT/p3/confs/argocd/application.yaml" | kubectl apply -f -
kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
    application/playground -n argocd --timeout=600s
kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
    application/playground -n argocd --timeout=600s
kubectl wait --for=condition=Available deployment/playground \
    -n dev --timeout=600s

# Expose Argo CD UI
if ! pgrep -f 'kubectl port-forward.*argocd-server' >/dev/null; then
    nohup kubectl port-forward --address 0.0.0.0 \
        -n argocd svc/argocd-server 8080:443 \
        >/tmp/argocd.log 2>&1 &
fi

kubectl get applications -n argocd
kubectl get pods,services -n dev
echo "App: http://localhost:8888/"
echo "Argo CD UI: https://localhost:8080/"
