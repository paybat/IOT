# Inception of Things

The root Vagrant machine is the parent VM for all three parts. It includes
Docker, K3d, kubectl, Vagrant, and VirtualBox with nested virtualization
enabled. P1 and P2 launch their Vagrant guests inside the parent. P3 runs
directly in the parent with K3d.

The root `Vagrantfile` creates the parent VM and provisions the full toolchain
for all three parts. Start it from the repository root on the host:

```sh
vagrant up
vagrant reload  # once after first provisioning, to load VirtualBox's kernel module
vagrant ssh
```

Run these parent VM commands only on the host. Do not run `vagrant ssh` from
inside `/workspace` or one of its subdirectories: Vagrant finds the root
`Vagrantfile` and tries to manage the already-running parent from inside
itself. VirtualBox rejects that because the host and guest use different user
IDs.

The parent uses 2 CPUs and 3 GB RAM. P1/P2 use reduced VM allocations to fit
within it. Run only one part at a time. Before P1/P2, stop P3's cluster with
`k3d cluster stop iot`; restart it afterward with `k3d cluster start iot`.
Inside the parent, the repository is mounted at `/workspace`:

```sh
cd /workspace
```

P1 and P2 both use `192.168.56.110`, so destroy or halt one before starting
the other. See each part's README for commands to run inside the parent.
In `/workspace/p3`, use `kubectl` and `k3d`; there is no separate P3 Vagrant
machine to SSH into.
P3's app is reachable from the host at `http://localhost:8888/`. Shut down or
remove the parent VM from the host at the repository root with `vagrant halt`
or `vagrant destroy`.
