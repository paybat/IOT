
#!/usr/bin/env bash
set -e

# Install required tools
apt-get update
apt-get install -y curl ca-certificates gnupg git software-properties-common linux-headers-generic

source /etc/os-release
arch=$(dpkg --print-architecture)

# Install Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# Install VirtualBox and Vagrant
add-apt-repository -y universe
add-apt-repository -y multiverse

curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $VERSION_CODENAME main" \
  > /etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install -y virtualbox virtualbox-dkms vagrant
modprobe vboxdrv || true

# Install kubectl
version=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSL "https://dl.k8s.io/release/$version/bin/linux/$arch/kubectl" \
  -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# Install k3d
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Allow Vagrant user to use Docker
usermod -aG docker vagrant

echo "Installation complete. Reconnect and run your projects."
