# Rancher management lab on Proxmox or bare metal

Start with [GitOps, the bootstrap order, and why the repos are separate](docs/START-HERE.md).

Rancher is a Kubernetes **management application**, not a Kubernetes distribution. This repository first builds a dedicated **K3s Kubernetes management cluster**, then installs Rancher using Helm. Rancher adds centralized inventory, access control and lifecycle visibility for other Kubernetes clusters. K3s is the distribution providing this example's API server, container runtime, pod networking and default Traefik ingress.

Keep your application workloads on a separate downstream cluster, such as the sibling `kubeadm-proxmox-lab`. A broken application should not consume the resources Rancher needs to manage it. This example uses one management server plus two management worker VMs and one Rancher replica. It is a learning topology, not HA: server/SQLite failure interrupts management. Production requires a reviewed three-server/etcd design, load balancing and separate failure domains.

## Reviewed version combination

Checked 2026-10-03: **Rancher 2.14.3**, **K3s v1.35.9+k3s1**, **cert-manager v1.20.4**, **Helm 3.20.x**. The [Rancher 2.14.3 support matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-14-3/) certifies K3s 1.33–1.35 for the management cluster. The [cert-manager supported releases table](https://cert-manager.io/docs/releases/) lists its Kubernetes compatibility; 1.20 supports this 1.35 baseline. Versioned upstream release artifacts were verified available. Rancher 2.14.4 has a published support-matrix page but was absent from both official Helm indexes during validation, so the example pins the available 2.14.3 chart instead. The [Rancher installation guide](https://ranchermanager.docs.rancher.com/v2.14/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster/) uses Helm 3 and cert-manager for generated TLS. [Helm 3 version compatibility](https://helm.sh/docs/v3/topics/version_skew/) lists 3.20.x with Kubernetes 1.32–1.35.

The installer is downloaded from the **K3s release tag**, not an unversioned curl-to-shell pipeline; `ansible/installer.lock.json` pins its SHA256. The installer itself checks release binary hashes. Existing K3s installs with different versions are refused rather than silently upgraded. This combination is selected for documented compatibility; it does not claim that every latest component version works together.

Use private inter-node TCP 6443/10250, UDP 8472 for default Flannel VXLAN, SSH administration, DNS/NTP and HTTPS egress. Restrict UDP 8472 to nodes; never expose it or API 6443 publicly. Expose management ingress 443 only to your trusted admin/downstream networks. Default K3s pod/service ranges are `10.42.0.0/16` and `10.43.0.0/16`; change K3s server flags before initial bootstrap if these overlap your network. Port 80 is needed only for a deliberately configured HTTP/ACME path, not this private generated-CA lab.

## Why start here, and how GitOps grows from it

A homelab gives you a place to learn failure recovery, networking and automation without buying a cloud fleet. Proxmox makes several disposable machines available on one physical server; declarative code records how they were built. Kubernetes adds scheduling and reconciliation when several container workloads outgrow one machine. Rancher can then centralize management of those clusters. Add each layer because it solves a problem you have, and measure the RAM, storage and operational cost.

Bootstrap your **local GitLab first** on infrastructure outside the Kubernetes cluster it will later manage. Then keep these VM/bootstrap files in an infrastructure repository and application/Helm YAML in a separate manifest repository. GitLab reviews and protected CI jobs can validate both. Install a narrowly scoped cluster agent only after Kubernetes is healthy. A GitOps controller such as Flux can later reconcile reviewed manifests from Git; KAS supplies agent/CI connectivity and is not itself that reconciler. Keeping GitLab outside this lab avoids the recovery cycle of needing a broken cluster to access the code that repairs it.

## Terraform and Kubernetes manifests have different jobs

Terraform here owns **Proxmox VMs, CPU/RAM/disks, bridge attachment and cloud-init addresses**. It does not create VLANs, router ACLs, DNS or the existing Ubuntu template. Ansible owns the dedicated hosts' OS/bootstrap configuration. Kubernetes YAML and Helm values own **objects inside the cluster**: Deployments, Services, RBAC, ingress, network policy and observability.

Keep VM state and Kubernetes deployment repositories separate as your lab grows. A runner plans Terraform with a narrowly scoped Proxmox token; an application pipeline applies reviewed manifests with namespace-scoped Kubernetes permissions. Removing a Deployment should not remove its VM. Destroying a VM does not make Terraform a backup tool for its workloads. Keep state encrypted, access controlled and backed up; this example starts with ignored local state for learning.

### Optional GitLab Agent (KAS)

The GitLab Agent for Kubernetes runs inside a cluster and makes an **outbound** connection to GitLab's Kubernetes Agent Server (KAS). Authorized GitLab CI jobs can use the agent's tunnel and generated kubeconfig contexts instead of exposing port 6443 to the internet. This does not grant every pipeline cluster-admin, or mean KAS automatically applies application YAML. GitOps reconciliation is a separate controller/workflow.

After creating the agent registration via the GitLab API, install the official agent Helm chart with its registration token delivered through a secret manager/protected local values file. Never commit that token. Put nonsecret configuration in `.gitlab/agents/lab/config.yaml` in the agent-config repository, for example:

```yaml
ci_access:
  projects:
    - id: example-group/lab-manifests
```

This Community Edition-compatible example uses the agent service account's permissions. Configure that service account with only the intended namespace/verbs and test `kubectl auth can-i`; do not accept a chart's cluster-admin default. CI-job impersonation with `access_as: ci_job` is an optional Premium/Ultimate feature, so it is not assumed by this CE lab. Authorizing a GitLab project is one trust gate; Kubernetes RBAC is another. Keep outbound HTTPS/WebSocket access to the correct KAS endpoint and validate its TLS certificate. Self-managed KAS configuration belongs to the GitLab administration repository, not the VM token or application manifests. See [GitLab agent CI workflow](https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/) and [agent installation](https://docs.gitlab.com/user/clusters/agent/install/).

## Proxmox prerequisites, in plain language

A **node** is a physical Proxmox host. A **template** is a reusable powered-off guest image. A **full clone** gets independent disks; a linked clone depends on its parent. A **datastore** stores virtual disks, and a **bridge** connects VM NICs to your lab network. **Cloud-init** sets first-boot user, public SSH keys, address, gateway and DNS; it does not install Kubernetes. The **QEMU guest agent** reports guest status to Proxmox.

Use an existing, tested Ubuntu Server 24.04 amd64 cloud-init template with `scsi0`, cloud-init drive, Python 3, passwordless sudo for `ubuntu`, SSH public-key authentication and an enabled QEMU guest agent. It must have clean machine identity/cloud-init state before templating. Verify its disk is no larger than the requested clone disk. Use `qm config TEMPLATE_ID` and `pvesm status` on Proxmox to inspect it. Template creation is intentionally outside this repository, so an unknown image is never imported or existing VM converted automatically.

Provide free VM IDs and unused addresses on a **dedicated private VLAN**, real bridge/datastore/node names and working DNS. `192.0.2.0/24` and `.example.test` are documentation placeholders, not an operational network. Avoid overlap between node, pod, service and VPN ranges. Confirm inter-node reachability and clock synchronization. For initial labs reserve 4 vCPUs, 8 GiB RAM and 40 GiB disk per VM; three VMs therefore need 24 GiB guest RAM plus host overhead.

Use a dedicated Proxmox API token. Scope its role/ACLs to the source template, a lab pool/VM paths and chosen storage; do not use a root token. Clone/configuration tasks require VM audit/clone/allocate/configuration/power privileges and storage audit/allocation. Token privilege separation requires both user and token ACLs. Compare permissions against the [provider authentication documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) before applying; never solve a 403 by blindly granting Administrator. API access uses verified HTTPS. Trust your Proxmox CA in the controller trust store; do not set `insecure=true`.

## Provisioning and bare metal

Install Terraform 1.6+, Ansible Core, Python 3 and SSH on your workstation. These examples use the pinned `bpg/proxmox` provider 0.115.0. No private SSH key is copied to Proxmox or Terraform.

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit the copy: actual template/node/storage/bridge, unused IDs/IPs and public keys.
# Set API identity privately, avoiding command-line/history credential literals:
export PROXMOX_VE_ENDPOINT=https://pve.example.test:8006/
read -r -s -p 'Proxmox API token: ' PROXMOX_VE_API_TOKEN; printf '\n'
export PROXMOX_VE_API_TOKEN
terraform init
terraform fmt -check
terraform validate
terraform plan -out=lab.tfplan
# Read the plan: only new intended VMs should appear. Run this only after your review.
terraform apply lab.tfplan
./scripts/inventory.sh
ansible-inventory --list
```

Accept SSH host keys only after verifying fingerprints from a trusted console/channel. This repository keeps SSH host-key checking enabled. Use `ssh-agent` or your local key file, never an inventory password. Check `ansible all -m ping` before bootstrapping. Terraform performs no remote-exec and does not run the bootstrap script automatically.

For bare metal, skip Terraform entirely. Supply fresh dedicated Ubuntu 24.04 machines with distinct hostnames/IPs, Python, SSH keys and passwordless sudo. Copy `ansible/inventory.baremetal.example.yml` to ignored `ansible/inventory.local.yml`, replace the documentation addresses, verify SSH fingerprints, then pass that inventory to the same bootstrap script. Nothing partitions disks or installs an OS.

## Cleanup, upgrades and evidence

There is no automatic destroy/reset action. Export workload data and take verified backups first. To remove this lab, review a deliberate source change removing `prevent_destroy`, then inspect `terraform plan -destroy` before any `terraform apply`. This destroys the managed VMs and their disks; it does not delete the original template. Bare-metal hosts are never wiped by this project. Kubernetes `drain`/uninstall/reset operations need separate review.

The bootstraps refuse implicit Kubernetes version changes. Recheck upstream support, take snapshots/backups, plan a documented Kubernetes/K3s upgrade and update version pins deliberately. Never call an untested snapshot your disaster-recovery plan: practice a restore in a separate isolated network to avoid duplicate node identities/IPs.

This is a **local review draft**. Static validation is not a live cluster test, security certification, HA claim or production deployment. No infrastructure was applied and no repository was published while preparing it.

## Create the management cluster and install Rancher

```sh
ansible all -m ping
LAB_BOOTSTRAP_ACK=yes ./scripts/bootstrap.sh
# Or use dedicated bare-metal hosts:
LAB_BOOTSTRAP_ACK=yes ./scripts/bootstrap.sh ansible/inventory.local.yml
mkdir -p .kube; chmod 700 .kube
ssh ubuntu@YOUR_MANAGEMENT_SERVER 'sudo cat /etc/rancher/k3s/k3s.yaml' > .kube/management.yaml
chmod 600 .kube/management.yaml
# Replace 127.0.0.1 in this private kubeconfig with the management server's private IP.
export KUBECONFIG="$PWD/.kube/management.yaml"
kubectl config current-context
kubectl get nodes -o wide
```

Do the kubeconfig address replacement with your editor or a local script, keeping its certificate/key data private. The generated server certificate covers its node IP. Give the context a distinct name to avoid confusing management/workload clusters. Point your chosen private DNS hostname at the management node's Traefik/ServiceLB ingress address using your DNS IaC. No external load balancer is provisioned here.

```sh
export EXPECTED_CONTEXT=YOUR_REVIEWED_MANAGEMENT_CONTEXT
export RANCHER_HOSTNAME=rancher.example.test
LAB_BOOTSTRAP_ACK=yes ./scripts/install-rancher.sh
kubectl -n cert-manager get pods
kubectl -n cattle-system get pods,ingress
kubectl -n cattle-system get certificates
```

`manifests/rancher-values.yaml` limits lab resource use, selects Traefik, one replica and strict agent TLS. Rancher generates the initial password, so it never appears in source or command arguments. Read it only in your private terminal and change it immediately through your chosen reviewed API workflow:

```sh
kubectl -n cattle-system get secret bootstrap-secret -o go-template='{{ .data.bootstrapPassword | base64decode }}'
```

### TLS and downstream trust

The example intentionally uses Rancher's generated private CA with cert-manager. Retrieve the CA via `kubectl -n cattle-system get secret tls-rancher -o jsonpath='{.data.ca\.crt}' | base64 --decode > .secrets/rancher-ca.pem` after creating private `.secrets/`. Import/trust that public CA through your device configuration management. Validate with `curl --cacert .secrets/rancher-ca.pem https://rancher.example.test/ping`; expect `pong`. Do not use `curl -k`, disable agent TLS verification or ignore browser certificate errors. If the certificate secret does not contain ca.crt, inspect the Certificate's issuer and retrieve the corresponding issuer CA instead; never substitute the server private key.

For a real hostname, replace generated TLS with a trusted public/private PKI certificate and its correct chain using the [Rancher TLS secret instructions](https://ranchermanager.docs.rancher.com/v2.14/getting-started/installation-and-upgrade/resources/add-tls-secrets/). TLS private keys stay outside Git. An ingress being Ready is not evidence that downstream agents trust its CA.

Register a separate workload cluster via Rancher's API/Terraform `rancher2` workflow in a **separate management configuration repository**, then apply its issued registration manifest using that workload cluster's restricted administrative context. Generated registration material is a credential: inspect the requested privileges, keep it out of Git, and verify the agent connects with strict TLS. This lab intentionally does not grant access to another cluster automatically.

### Backups and troubleshooting

For this single-server SQLite lab, preserve the K3s datastore, server token and TLS material using the [K3s backup guidance](https://docs.k3s.io/datastore/backup-restore); coordinated file copies require a planned service stop, and no stop is automated here. Embedded-etcd snapshots apply to an HA etcd topology, not this SQLite server. Add the [Rancher backup operator](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/backup-restore-and-disaster-recovery/) for Rancher application resources and protect its encryption configuration/backup destination. Neither backup replaces downstream application/PV backups.

If Helm times out, inspect `kubectl -n cattle-system describe pod`, ingress events and cert-manager Certificate/Issuer status. For networking inspect `journalctl -u k3s`, `journalctl -u k3s-agent`, DNS resolution and node firewall rules. A Rancher pod may be healthy while DNS/TLS/WebSocket routing is broken. Plan and rehearse restores and upgrades in a separate isolated lab; keep the previous versioned values alongside the protected backup.

## Optional observability

Use a separate manifest/Helm repository for Grafana, Loki (logs), Tempo (traces), Mimir (metrics) and Alloy collection. Log collection does **not** automatically create application traces: instrument applications with OpenTelemetry and configure trace export. Metrics also need explicit scrape/export configuration, retention and storage. Small single-replica labs trade availability for lower resource use; do not mistake them for production architectures.
