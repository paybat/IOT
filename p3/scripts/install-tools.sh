#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )) || ! grep -q '^ID=ubuntu$' /etc/os-release; then
  echo "Run as root on Ubuntu (Vagrant does this automatically)." >&2
  exit 1
fi

arch="$(dpkg --print-architecture)"
case "$arch" in amd64|arm64) ;; *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; esac
source /etc/os-release

# Install Docker from its official Ubuntu package repository.
apt-get update
apt-get install -y ca-certificates curl gnupg git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# P1 and P2 run as nested Vagrant guests inside the parent VM.
apt-get install -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y multiverse
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
chmod 0644 /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=${arch} signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${UBUNTU_CODENAME:-$VERSION_CODENAME} main" >/etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y linux-headers-generic virtualbox-dkms virtualbox vagrant
if ! modprobe vboxdrv; then
  echo "VirtualBox kernel module isn't available yet. On the host, run 'vagrant reload' once after provisioning." >&2
fi

# Install the latest stable kubectl and k3d.
kubectl_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${arch}/kubectl"
chmod 755 /usr/local/bin/kubectl
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Let the VM user run Docker without sudo; group changes need a new login.
user="${SUDO_USER:-vagrant}"
if id "$user" >/dev/null 2>&1 && [[ "$user" != root ]]; then
  usermod -aG docker "$user"
  echo "Installed. Reconnect, then run P1/P2 with Vagrant or P3 with: bash /workspace/p3/scripts/create-cluster.sh"
else
  echo "Installed. Add your user to the docker group, reconnect, then run /workspace/p3/scripts/create-cluster.sh."
fi
