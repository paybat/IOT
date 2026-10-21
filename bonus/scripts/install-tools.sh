#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git gnupg

if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    arch="$(dpkg --print-architecture)"
    echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
        >/etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
usermod -aG docker vagrant

if ! command -v kubectl >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"
    kubectl_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    curl -fsSL "https://dl.k8s.io/release/$kubectl_version/bin/linux/$arch/kubectl" \
        -o /usr/local/bin/kubectl
    chmod 0755 /usr/local/bin/kubectl
fi

if ! command -v k3d >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

echo "Bonus parent tools installed. Reconnect with 'vagrant ssh' so Docker group membership takes effect."
