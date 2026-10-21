#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GITLAB_HOST=gitlab.gitlab.svc.cluster.local
GITLAB_PUSH_PORT=18081
PROJECT_PATH=root/iot-hidriouc

command -v kubectl >/dev/null
command -v git >/dev/null
kubectl rollout status statefulset/gitlab -n gitlab --timeout=3600s
GITLAB_POD="$(kubectl get pod -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}')"

# The assignment's GitLab instance is a local learning service. Create a public
# read-only project so Argo CD can clone it from inside the Kubernetes cluster.
kubectl exec -n gitlab "$GITLAB_POD" -- gitlab-rails runner \
  'root = User.find_by_username!("root"); project = Project.find_by_full_path("root/iot-hidriouc"); unless project; project = Projects::CreateService.new(root, { name: "iot-hidriouc", path: "iot-hidriouc", namespace_id: root.namespace.id, visibility_level: Gitlab::VisibilityLevel::PUBLIC }).execute; raise project.errors.full_messages.join(", ") unless project.persisted?; end; project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC) unless project.visibility_level == Gitlab::VisibilityLevel::PUBLIC'

password="$(kubectl get secret gitlab-root -n gitlab -o jsonpath='{.data.password}' | base64 -d)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/repo/p3/confs"
cp -R "$REPO_ROOT/p3/confs/app" "$tmpdir/repo/p3/confs/app"
git -C "$tmpdir/repo" init --initial-branch=main >/dev/null
git -C "$tmpdir/repo" config user.name "IOT bonus bootstrap"
git -C "$tmpdir/repo" config user.email "iot-bonus@localhost"
git -C "$tmpdir/repo" add p3/confs/app
git -C "$tmpdir/repo" commit -m "Add Part 3 playground app" >/dev/null

# Askpass keeps the generated password out of the Git remote URL and logs.
cat >"$tmpdir/askpass" <<'ASKPASS'
#!/bin/sh
case "$1" in
  *sername*) printf '%s\n' root ;;
  *) printf '%s\n' "$GITLAB_ROOT_PASSWORD" ;;
esac
ASKPASS
chmod 700 "$tmpdir/askpass"
# The parent VM cannot resolve Kubernetes service DNS. Temporarily forward the
# Service to localhost for the push; Argo CD later pulls through cluster DNS.
kubectl port-forward --address 127.0.0.1 -n gitlab \
  svc/gitlab "$GITLAB_PUSH_PORT:80" >"$tmpdir/port-forward.log" 2>&1 &
port_forward_pid=$!
trap 'kill "$port_forward_pid" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT
for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:$GITLAB_PUSH_PORT/users/sign_in" >/dev/null; then
        break
    fi
    sleep 1
done
repo_url="http://127.0.0.1:$GITLAB_PUSH_PORT/$PROJECT_PATH.git"
if ! git -C "$tmpdir/repo" ls-remote --exit-code "$repo_url" \
    refs/heads/main >/dev/null 2>&1; then
    GITLAB_ROOT_PASSWORD="$password" GIT_ASKPASS="$tmpdir/askpass" \
      GIT_TERMINAL_PROMPT=0 git -C "$tmpdir/repo" -c credential.helper= \
        push "$repo_url" main
else
    echo "GitLab project $PROJECT_PATH already has main; leaving it unchanged."
fi

kubectl apply -f "$SCRIPT_DIR/../confs/argocd/application.yaml"
kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
  application/playground -n argocd --timeout=900s
kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
  application/playground -n argocd --timeout=900s
kubectl wait --for=condition=Available deployment/playground \
  -n dev --timeout=600s

kubectl get application playground -n argocd
kubectl get pods,services -n dev
echo "Part 3 app: http://localhost:8888/"
