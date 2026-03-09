# proxmox-k3s

[![Terraform](https://img.shields.io/github/actions/workflow/status/ngutech21/proxmox-k3s/terraform.yml?branch=master&label=Terraform)](https://github.com/ngutech21/proxmox-k3s/actions/workflows/terraform.yml)
[![Ansible](https://img.shields.io/github/actions/workflow/status/ngutech21/proxmox-k3s/ansible.yml?branch=master&label=Ansible)](https://github.com/ngutech21/proxmox-k3s/actions/workflows/ansible.yml)
[![Actionlint](https://img.shields.io/github/actions/workflow/status/ngutech21/proxmox-k3s/actionlint.yml?branch=master&label=Actionlint)](https://github.com/ngutech21/proxmox-k3s/actions/workflows/actionlint.yml)

Opinionated infrastructure repo for bringing up a highly available `k3s` cluster on top of Proxmox VMs with one workflow.

After you initialize the two local config files, `just up` provisions the VMs, prepares the operating system, bootstraps HA `k3s`, and installs the core platform services.

## 💡 What You Get

If you want a reproducible HA `k3s` setup on Proxmox without spending time on glue code, this repo gives you a working path out of the box.

Instead of manually combining VM provisioning, cloud-init, node preparation, `k3s` bootstrap, ingress, storage, certificates, and upgrades, you get one opinionated workflow with sensible defaults and a small configuration surface.

The main value is not just that it installs Kubernetes. The value is that it removes the repetitive work around Kubernetes on Proxmox:

- no hand-maintained inventory or stage-specific config files
- no manual install order across Terraform, Ansible, and Helm
- no separate setup for ingress, storage, cert-manager, and upgrade management
- no need to re-figure out a HA layout every time you build a new lab

## ✨ Benefits

- Bring up a complete HA `k3s` platform on Proxmox with `just up`
- Keep local configuration limited to `cluster.tfvars` and `cluster.secrets.tfvars`
- Scale the cluster shape up or down by changing `cluster_nodes` for control-plane and worker VMs
- Reuse generated inventory and derived values instead of editing multiple stage configs by hand
- Get opinionated defaults for kube-vip, Traefik, cert-manager, Longhorn, and upgrade management
- Prepare every node automatically, including unattended APT security updates
- Set up Longhorn disks automatically on worker nodes, including partitioning, formatting, mounting, and persistence
- Re-run the full lifecycle through stable `just` commands instead of ad-hoc shell history

## 🚀 What gets installed

- Proxmox VMs for control-plane and worker nodes
- Debian node preparation with required packages, kernel settings, swap disablement, and unattended upgrades
- HA `k3s` with embedded etcd and kube-vip for the API VIP and LoadBalancer IPs
- `cert-manager` including bootstrap issuers and root CA materials
- `system-upgrade-controller` for cluster upgrade plans
- `Traefik` as the ingress controller installed via Helm
- `Longhorn` for distributed block storage
- `CloudNativePG` operator for PostgreSQL workloads
- `metrics-server` from the base `k3s` installation
- example workloads under `05-examples`


## 🧰 Requirements

- one or more Proxmox nodes with API access
- a Proxmox API token with permission to clone and create VMs
- a cloud-init capable VM template on every Proxmox node you reference in `cluster_nodes`
- matching `template_id` values in `cluster.tfvars` for those templates on the target nodes
- `VS Code` with the dev container is recommended so the toolchain stays consistent
- `Docker Desktop` or an equivalent container runtime for the dev container workflow

Everything else is expected to come from the dev container.

## ⚡ Quick Start

This is the shortest path to a running cluster:

```bash
just init-config
```

Edit the two generated local files:

- `cluster.tfvars` for non-secret cluster configuration
- `cluster.secrets.tfvars` for Proxmox credentials and the shared bootstrap token

Then run the standard end-to-end workflow:

```bash
just up
```

`just up` runs these tasks in order:

1. `just init-config`
2. `just provision-vms`
3. `just configure-vms`
4. `just bootstrap-cluster`
5. `just install-core`

After bootstrap, `k3s-ansible` copies the kubeconfig to your control machine and merges it into `~/.kube/config` with the `proxmox-k3s` context.

You can then access the cluster with:

```bash
kubectl --context proxmox-k3s get nodes
```

For most users, this is the main reason to use the repo: you describe the cluster once, run one command, and get a Proxmox-backed HA `k3s` environment with ingress, storage, certificates, and upgrade plumbing already in place.

## 🏗️ Cluster Layout

The cluster shape is defined in `cluster.tfvars` through `cluster_nodes`.

- You can choose how many control-plane nodes you want
- You can choose how many worker nodes you want
- Each node can be pinned to a specific Proxmox host and template
- CPU, memory, and other VM defaults can stay global, with optional per-node overrides

A typical HA layout is `3` control-plane nodes plus `2` or more worker nodes, but smaller and larger layouts work as long as at least one enabled control-plane node exists.

## ⚙️ Configuration Model

The user-edited local inputs are intentionally reduced to two gitignored files in the repository root.

### `cluster.tfvars`

This file contains non-secret cluster settings such as:

- Proxmox URL and TLS mode
- explicit node placement and `template_id` mapping
- VM sizing and datastore defaults
- API VIP and kube-vip service range
- DNS suffix and smoke-test toggle
- SSH user and public key for cloud-init

### `cluster.secrets.tfvars`

This file contains:

- `proxmox_api_token_id`
- `proxmox_api_token_secret`
- `cluster_bootstrap_token`

Terraform consumes those files and generates the downstream artifacts used by Ansible and Helmfile.

## 🧾 Generated Files

These files are derived and should not be edited manually:

- `ansible/inventory/hosts.yml`
- `.generated/bootstrap.vars.yml`
- `.generated/core.values.yaml`

If you only changed `cluster.tfvars` or `cluster.secrets.tfvars` and want to refresh generated artifacts without reprovisioning VMs, use:

```bash
just sync-config
```

## 🔧 Main Commands

- `just provision-vms`: create or update the Proxmox VMs and refresh generated artifacts
- `just configure-vms`: prepare the nodes with base OS configuration and Longhorn disk setup
- `just bootstrap-cluster`: install HA `k3s` with kube-vip and merge kubeconfig locally
- `just install-core`: install the Helmfile-managed platform stack and upgrade plans
- `just verify-bootstrap`: re-run bootstrap validation
- `just verify-core`: re-run core platform validation
- `just bootstrap-cert-manager`: re-run only the cert-manager bootstrap release
- `just destroy-cluster`: destroy the Terraform-managed VM infrastructure

## 📁 Repo Layout

- [`01-provision`](01-provision): Terraform for Proxmox VMs and generated downstream config
- [`02-configure`](02-configure): Ansible base host preparation
- [`03-bootstrap`](03-bootstrap): HA `k3s` bootstrap with `k3s-ansible`
- [`04-core`](04-core): Helmfile-managed cluster services
- [`05-examples`](05-examples): example workloads for testing the setup
