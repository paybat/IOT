# P3 — K3d and Argo CD in a VM

The subject requires P3 to run on a virtual machine. This Vagrant environment
creates an Ubuntu guest; Docker, K3d, Kubernetes, and Argo CD all run inside
that guest. Vagrant forwards the app at guest port `8888` to host port `8888`.
Argo CD runs in the `argocd` namespace and watches this public GitHub
repository. It syncs `p3/confs/app` into `dev`; pushing an image tag change to
Git updates the running application.

P1 and P2 also use their own Vagrant VMs. They each use `192.168.56.110`, so
run one part at a time. P3 needs about 4 GB of guest RAM; halt the other lab
VMs before starting it on a host with limited memory.

## 1. Publish the repository

Create a **public** GitHub repository whose name contains a team member's
login, add this project, and push the `p3` directory. Argo CD needs public
read access so no deploy key or token is required. The GitHub URL used below
must point to that repository, for example
`https://github.com/LOGIN/iot-LOGIN.git`.

## 2. Start the P3 VM and install tools

From this directory, start the VM. Vagrant runs the tool installer during
provisioning:

```sh
vagrant up
```

The VM has 2 CPUs and 4 GB RAM. Inside the VM, confirm Docker access and move
to the shared project directory:

```sh
docker info
cd /workspace
```

Open the VM shell with `vagrant ssh` from another host terminal. Commands
below that use `kubectl` or `k3d` run in that VM shell.

The installer adds the `vagrant` user to the Docker group. Start a fresh SSH
session after provisioning if `docker info` reports a permission error.

## 3. Create the cluster and deploy

Inside the VM, run this from `/workspace`, replacing the URL with your public
repository:

```sh
GIT_REPO_URL=https://github.com/LOGIN/iot-LOGIN.git \
  bash p3/scripts/create-cluster.sh
```

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

From the host machine, check the app through Vagrant's forwarded port:

```sh
curl http://localhost:8888/
```

The first successful response should contain `"message":"v1"`. If the
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

Edit `p3/confs/app/deployment.yaml`, change `wil42/playground:v1` to
`wil42/playground:v2`, commit, and push to the public GitHub repository. Argo CD
polls the repository and applies the new desired state automatically. Observe
`kubectl get applications -n argocd -w`, then verify:

```sh
kubectl get deployment playground -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Run `curl http://localhost:8888/` from the host terminal to confirm the new
version.

The image should be `wil42/playground:v2` and the response should identify
`v2`. To return to v1, revert the commit or change the tag and push again.

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

```sh
vagrant halt
```

To remove the VM and its local data as well:

```sh
vagrant destroy
```

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
