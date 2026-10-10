#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo: sudo bash p3/scripts/install-tools.sh" >&2
  exit 1
fi

if ! grep -q '^ID=ubuntu$' /etc/os-release; then
  echo "This installer currently supports Ubuntu. Install Docker Engine, kubectl, and k3d manually on other distributions." >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
source /etc/os-release
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

stable_kubectl="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
case "$(dpkg --print-architecture)" in
  amd64) kubectl_arch=amd64 ;;
  arm64) kubectl_arch=arm64 ;;
  *) echo "Unsupported architecture for kubectl: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${stable_kubectl}/bin/linux/${kubectl_arch}/kubectl"
chmod 0755 /usr/local/bin/kubectl

curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

target_user="${SUDO_USER:-}"
if [[ -z "$target_user" ]] && id vagrant >/dev/null 2>&1; then
  # Vagrant shell provisioners can run as root without preserving SUDO_USER.
  target_user=vagrant
fi
if [[ -n "$target_user" && "$target_user" != root ]]; then
  usermod -aG docker "$target_user"
  echo "Installed Docker, kubectl, and k3d. Log out and back in so '${target_user}' receives Docker group access, then run:"
  echo "  bash p3/scripts/create-cluster.sh"
else
  echo "Installed Docker, kubectl, and k3d. Add your normal user to the docker group, start a new login session, then run p3/scripts/create-cluster.sh."
fi
