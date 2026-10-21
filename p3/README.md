# P3 — K3d and Argo CD in a VM

The root Vagrant machine is the parent VM for this repository. Docker, K3d,
Kubernetes, and Argo CD run directly inside it, as the subject says Part 3 is
without another Vagrant machine. P1 and P2 launch nested Vagrant guests from
the parent. Argo CD runs in the `argocd`
namespace and watches this public GitHub repository. It syncs
`p3/confs/app` into `dev`; pushing an image tag change to Git updates the
running application.

Start the parent from the repository root on the host with `vagrant up`, then
connect using `vagrant ssh`. The repository is mounted at `/workspace`. The
parent VM allocates 2 CPUs and 3 GB RAM. P1 and P2 each use
`192.168.56.110`; run those parts separately, and stop the K3d cluster while
either nested lab is running to keep memory use within the parent allocation.
Run the parent `vagrant up`, `vagrant reload`, and `vagrant ssh` commands on
the host only. Inside `/workspace/p3`, use `kubectl` and `k3d`; a `vagrant ssh`
there would target the root parent project again and VirtualBox would reject
the different host and guest user IDs.

## 1. Publish the repository

The project is currently pushed to the public origin
`https://github.com/paybat/IOT.git`. The subject requires the repository name
to contain a team member's login; if `IOT` does not meet your team's login,
create or rename the repository accordingly and update `origin`. Argo CD needs
public read access, so no deploy key or token is required.

## 2. Start the P3 VM and install tools

From the repository root on the host, start the parent VM. Its provisioner
installs Docker, K3d, kubectl, Git, Vagrant, and VirtualBox:

```sh
vagrant up
vagrant reload  # once after first provision, to load VirtualBox's kernel module
vagrant ssh
```

Inside the parent, confirm Docker access and move to the shared project directory:

```sh
docker info
cd /workspace
```

Commands below that use `kubectl` or `k3d` run in this parent VM shell.

The installer adds the `vagrant` user to the Docker group. Start a fresh SSH
session after provisioning if `docker info` reports a permission error.

## 3. Create the cluster and deploy

Inside the VM, run this from `/workspace`. The script reads the URL from the
Git `origin` remote:

```sh
bash p3/scripts/create-cluster.sh
```

If the URL differs from `origin`, pass the public URL explicitly with
`GIT_REPO_URL=https://github.com/LOGIN/iot-LOGIN.git`.

The cluster is named `iot` by default and has one server and one agent. K3d
maps VM port `8888` to the Kubernetes NodePort `30088`. Vagrant forwards that
VM port to host port `8888`. The script installs
Argo CD from its official stable manifest, then registers the `playground`
Application. Argo CD creates `dev` and syncs the checked-in app manifests.

Check cluster state inside the VM:

```sh
kubectl get nodes
kubectl get namespaces argocd dev
kubectl get applications -n argocd
kubectl get pods,services -n dev
```

From the host machine, check the app through the parent's forwarded port:

```sh
curl http://localhost:8888/
```

The current committed manifest selects `wil42/playground:v2`, so the successful
response should contain `"message":"v2"`. The repository history contains
the earlier v1 state and the later v2 update. If the
application is not ready yet, wait for the `playground` Application to become
`Synced` and `Healthy`, then retry.

## 4. Open the Argo CD UI

In a terminal, forward the UI service:

```sh
kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8080:443
```

Vagrant forwards guest port `8080` to the host. Open <https://localhost:8080>
on the host. Retrieve the initial admin password in another guest terminal:

```sh
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

The username is `admin`. This password is for the local lab; change it if the
instance will remain accessible beyond the exercise.

## 5. Demonstrate GitOps version change

The repository currently selects v2. To demonstrate a live update, change the
tag to `v1`, commit, and push. Argo CD polls the repository and applies that
state. Then change it back to `v2`, commit, and push again. Observe
`kubectl get applications -n argocd -w`, then verify:

```sh
kubectl get deployment playground -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Run `curl http://localhost:8888/` from the host terminal to confirm the new
version.

After the second push, the image should be `wil42/playground:v2` and the
response should identify `v2`.

## How the pieces fit

```text
GitHub (desired YAML) -> Argo CD (argocd namespace) -> Deployment + Service (dev)
                                                        ^
browser/curl -> localhost:8888 -> K3d port map -> NodePort 30088
```

- **K3s vs K3d:** K3s is the lightweight Kubernetes distribution. K3d is a
  tool that runs K3s nodes as Docker containers and creates a local cluster.
- **GitOps:** Git is the source of truth. Argo CD continuously compares the
  live cluster with the manifests at the configured repository path and
  reconciles drift. Automated sync makes a pushed tag change become a rollout.
- **Deployment:** Kubernetes replaces the Pod when its image changes and keeps
  the requested replica count at one.
- **Service and NodePort:** the Service selects the Pod by label and exposes
  port 30088 on the node. K3d forwards host port 8888 to that NodePort.

## Cleanup

Run `vagrant halt` from the repository root on the host to stop the parent VM.

To remove the VM and its local data as well:

Run `vagrant destroy` from the repository root on the host to remove the
parent VM and its local data.

To delete only the K3d cluster while keeping the VM:

```sh
k3d cluster delete iot
```

## Troubleshooting

- `docker info` permission denied: log out and back in after the installer
  adds your user to the Docker group.
- Argo CD reports repository errors: verify the repository is public, the URL
  ends in `.git`, and `p3/confs/app` exists on the default branch.
- The app stays `Progressing`: inspect `kubectl describe pod -n dev` and
  `kubectl logs -n dev deployment/playground`.
- `curl` fails: confirm the Pod is ready and Service has an endpoint using
  `kubectl get endpoints -n dev playground`.

## Official references

- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Install kubectl on Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [K3d installation](https://k3d.io/stable/)
- [Argo CD installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Argo CD getting started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
