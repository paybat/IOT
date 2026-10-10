#!/usr/bin/env bash
set -euo pipefail

cluster_name="${K3D_CLUSTER_NAME:-iot}"
repo_url="${GIT_REPO_URL:-}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is unavailable to this user. Run install-tools.sh, then log out and back in (or use a Docker-enabled session)." >&2
  exit 1
fi
if [[ -z "$repo_url" ]]; then
  echo "Set GIT_REPO_URL to the public HTTPS URL of your GitHub repository, e.g.:" >&2
  echo "  GIT_REPO_URL=https://github.com/LOGIN/REPOSITORY.git bash p3/scripts/create-cluster.sh" >&2
  exit 1
fi
if [[ ! "$repo_url" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?$ ]]; then
  echo "GIT_REPO_URL must be a public HTTPS GitHub repository URL, optionally ending in .git." >&2
  exit 1
fi
for tool in k3d kubectl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required command '$tool' was not found. Run p3/scripts/install-tools.sh first." >&2
    exit 1
  fi
done

if ! k3d cluster list -o json | grep -Eq '"name"[[:space:]]*:[[:space:]]*"'"$cluster_name"'"'; then
  k3d cluster create "$cluster_name" --agents 1 -p "8888:30088@server:0"
fi

kubectl config use-context "k3d-${cluster_name}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s

sed "s|__GIT_REPO_URL__|${repo_url}|g" "$repo_root/p3/confs/argocd/application.yaml" | kubectl apply -f -

# Registering an Application is asynchronous. Wait until Argo CD has fetched
# the repository and completed its first sync before looking for its workload.
wait_for_app_status() {
  local jsonpath="$1" expected="$2" description="$3" deadline=$((SECONDS + 300)) value
  while (( SECONDS < deadline )); do
    value="$(kubectl get application playground -n argocd -o "jsonpath=${jsonpath}" 2>/dev/null || true)"
    if [[ "$value" == "$expected" ]]; then
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for Argo CD Application to become ${description}." >&2
  kubectl get application playground -n argocd -o yaml >&2 || true
  return 1
}

wait_for_app_status '{.status.sync.status}' Synced 'Synced'
wait_for_app_status '{.status.health.status}' Healthy 'Healthy'
kubectl wait --for=condition=Available deployment/playground -n dev --timeout=300s
kubectl get applications -n argocd
kubectl get pods,services -n dev
echo "App endpoint: http://localhost:8888/"
