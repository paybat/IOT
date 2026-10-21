# Bonus: local GitLab for Part 3

The bonus runs inside the same parent VM as the rest of the lab. It deploys
the official GitLab CE Omnibus image into the required `gitlab` namespace on
the existing Part 3 K3d cluster, then points the existing Argo CD `playground`
application at a local GitLab project containing the Part 3 app manifests.
The Part 1, Part 2, and Part 3 files are not changed by the bonus.

The official image tag used here is `gitlab/gitlab-ce:19.5.0-ce.0`, the latest
stable CE release available when this bonus was prepared. The single-container
Omnibus deployment is for this constrained learning VM; it is not a production
GitLab topology.

## Run from the host

On a host with 16 GB RAM, start or resize the root parent VM with 4 CPUs and
10 GB RAM:

```sh
IOT_BONUS=1 IOT_VM_CPUS=4 IOT_VM_MEMORY_MB=10240 vagrant up
vagrant ssh
```

If the parent VM already exists, run
`IOT_BONUS=1 IOT_VM_CPUS=4 IOT_VM_MEMORY_MB=10240 vagrant provision` to install
the bonus toolchain. Reload it only after changing its CPU or memory allocation.

The extra memory is needed for GitLab alongside K3d and Argo CD. The root
Vagrantfile still defaults to its smaller Part 1–3 allocation; only the
commands above select the bonus allocation. Port 8081 is forwarded from the
parent for the GitLab UI.

## Run inside the parent VM

```sh
cd /workspace
./bonus/scripts/create-cluster.sh
./bonus/scripts/deploy-gitlab.sh
./bonus/scripts/bootstrap-gitops.sh
```

The first GitLab startup takes several minutes. GitLab is available at
`http://localhost:8081/` (user `root`). Read its generated password inside the
parent VM with:

```sh
kubectl get secret gitlab-root -n gitlab -o jsonpath='{.data.password}' | base64 -d; echo
```

The application remains available at `http://localhost:8888/`. Argo CD fetches
the app from `http://gitlab.gitlab.svc.cluster.local/root/iot-hidriouc.git` over
the in-cluster GitLab Service. To inspect the bonus deployment, use
`kubectl get pods,svc,pvc -n gitlab` and
`kubectl get application playground -n argocd`.
