# P2 — K3s, three apps, and Ingress

Run P2 inside the parent VM from `/workspace/p2`. It creates one nested
single-server VM at
`192.168.56.110`. Its VM hostname ends with uppercase `S`;
the Kubernetes node identity uses a lowercase name because
Kubernetes node names must be DNS compatible. K3s installs its default Traefik
Ingress controller. Three Deployments run nginx with distinct
HTML content; `app2` has three replicas. Services give each Deployment a stable
in-cluster address. Ingress resources route by the HTTP `Host` header; a
separate default Ingress sends unmatched hosts to `app3`.

The nested VM allocates 1 CPU and 1.5 GB RAM so it fits inside the parent's
fixed 3 GB allocation. Before starting P2, stop P3's K3d cluster from the
parent with `k3d cluster stop iot`; restart it with `k3d cluster start iot`
after P2 is halted or destroyed.

## Launch

```sh
cd /workspace/p2
export VAGRANT_DOTFILE_PATH=/home/vagrant/.vagrant-p2
LOGIN=yourlogin vagrant up
```

The separate state directory keeps P2's Vagrant metadata separate from P1.

From the parent VM, send requests with different Host headers:

```sh
curl -H 'Host: app1.com' http://192.168.56.110/
curl -H 'Host: app2.com' http://192.168.56.110/
curl -H 'Host: unknown.example' http://192.168.56.110/
```

Expected page headings are `app1`, `app2`, and `app3`. You can add
`192.168.56.110 app1.com app2.com` to your host's hosts file to use browser
URLs. The curl form makes the Host-header behavior explicit.

Inspect from the VM:

```sh
export VAGRANT_DOTFILE_PATH=/home/vagrant/.vagrant-p2
cd /workspace/p2
vagrant ssh yourloginS
sudo k3s kubectl get deployments,pods,services,ingress -o wide
sudo k3s kubectl describe ingress apps
sudo k3s kubectl get pods -n kube-system
```

## Understand the request path

```text
client -> VM:80 -> Traefik Ingress -> host rule/default -> Service -> ready Pod(s)
```

- The **Ingress** is a routing rule; it is not itself the proxy process.
- **Traefik** watches Ingress resources and handles HTTP on port 80.
- Each **Service** selects Pods by labels and gives them a stable virtual IP.
- A **Deployment** maintains the requested Pod count and replaces failed Pods.
- The `app2` Service sends connections to its ready endpoints. Three replicas
  add capacity and basic resilience, not three different apps.

Kubernetes applies these files declaratively: YAML describes desired state and
controllers reconcile actual state toward it. ConfigMaps provide each nginx
container's page without building three separate images. The image tag is
versioned (`nginx:1.30.5-alpine3.24`) so a later upstream release does not
silently change this lab's chosen version. [The tag is listed by the official
nginx image on Docker Hub.](https://hub.docker.com/_/nginx/tags)

## Learn by breaking and repairing

1. Change `app2.spec.replicas` to `1`, apply the files, and observe the count.
2. Set it back to `3`; watch with `sudo k3s kubectl get pods -w`.
3. Change the app1 Ingress host and explain why the old Host header stops
   matching.
4. Inspect `sudo k3s kubectl get endpoints app2`; connect its addresses to the
   Service selector (`app: app2`) and the Pod labels.
5. Delete one app2 Pod and watch the Deployment create a replacement.

Apply changed manifests from the VM with
`sudo k3s kubectl apply -f /vagrant/confs/`. Tear down with `vagrant destroy`
when finished.
