# P1 — K3s with Vagrant

Run these commands inside the parent VM, from `/workspace/p1`. This part
creates two nested Ubuntu VMs on a private network. The `S` machine runs the
K3s control plane; `SW` runs the K3s agent. Vagrant provisions them over
SSH with its generated key, so `vagrant ssh <machine>` does not ask for a
password.

## Start and inspect

```sh
cd /workspace/p1
export VAGRANT_DOTFILE_PATH=/home/vagrant/.vagrant-p1
LOGIN=yourlogin vagrant up
vagrant status
vagrant ssh yourloginS
```

The default login is `hidriouc`. Replace it with the team login and use that
same value for all commands. The VM hostnames are `<login>S` and `<login>SW`, at
`192.168.56.110` and `192.168.56.111`. Kubernetes node identities are the
lowercase names `<login>s` and `<login>sw`; Kubernetes requires DNS compatible
node names even though the assignment asks for uppercase suffixes in hostnames.

The guests use Bento's Ubuntu 24.04 box. Canonical stopped publishing new
Vagrant boxes starting with Ubuntu 24.04, so this uses a maintained Vagrant box
source instead of relying on the discontinued `ubuntu/noble64` publication.

The nested server is allocated 1 CPU and 1.25 GB RAM; the agent gets 1 CPU and
768 MB. These reduced allocations keep the complete lab within the parent's
fixed 3 GB. Before starting P1, stop P3's K3d cluster from the parent with
`k3d cluster stop iot`. Restart it with `k3d cluster start iot` after P1 is
halted or destroyed. If K3s is slow to become ready, give it time to start
before joining the worker.

On the server, inspect the cluster:

```sh
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
```

Both nodes should become `Ready`. K3s installs `kubectl` as `k3s kubectl` and
writes its kubeconfig to `/etc/rancher/k3s/k3s.yaml`.
The node `INTERNAL-IP` values should be `.110` and `.111`, not the Vagrant
NAT address `10.0.2.15`.

## What each part teaches

- **Vagrantfile:** desired VM state, names, CPU/RAM, static private networking,
  and repeatable provisioning.
- **Server install:** starts the Kubernetes API/control plane and accepts
  agents. Its generated join token is at
  `/var/lib/rancher/k3s/server/node-token`.
- **Agent install:** connects to `https://192.168.56.110:6443` and presents the
  same token. The token is a cluster join credential.
- **kubectl:** queries the Kubernetes API. `Ready` means the node registered
  and passed basic health checks; it does not guarantee every workload is
  healthy.

The Vagrantfile uses an obvious shared token for this isolated learning lab.
Override it using `K3S_TOKEN='your-private-lab-token'` when starting Vagrant.
Never reuse a lab token in a real cluster. K3s warns that this short lab token
does not include the server CA hash, so the joining agent cannot authenticate
the server certificate during bootstrap. Production clusters should distribute
the full secure node token through a secret manager or another protected
channel. Finish and destroy P1 before starting P2: both use `192.168.56.110`
inside the parent VM and cannot run together. P3's K3d cluster must also be
stopped while P1 is running to leave enough memory for the nested guests.

## Useful commands

```sh
export VAGRANT_DOTFILE_PATH=/home/vagrant/.vagrant-p1
cd /workspace/p1
vagrant ssh yourloginS
vagrant ssh yourloginSW
vagrant provision yourloginSW
vagrant halt
vagrant destroy
```

`destroy` deletes the VMs and their local state. Recreating them provisions a
fresh cluster.

## Explain it from memory

1. Which machine runs the Kubernetes API, and where does the agent connect?
2. Why does each VM usually have a NAT interface and a private-network
   interface? Which address is used for the cluster join?
3. What does the join token protect, and why should it stay private?
4. What does `kubectl get nodes` prove, and what does it not prove?
5. If the worker is missing, check `systemctl status k3s-agent`, connectivity
   to TCP 6443, the configured server URL and token, then server-side events.
