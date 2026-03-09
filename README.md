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

## 🧱 Optional Template Bootstrap

If you do not already have a cloud-init capable Debian template on each Proxmox node, you can create one with the optional `00-create-template` stage.

This stage uses Ansible against the Proxmox hosts directly and creates a Debian Trixie template that:

- downloads the official Debian Trixie generic image
- imports it with `qm importdisk`
- enables Cloud-Init
- enables the Proxmox QEMU guest agent flag
- marks the VM as a reusable Proxmox template

The stage is intentionally fail-fast:

- if the configured VM ID already exists on a node, it aborts
- if the configured template name already exists on a node, it aborts
- if the image is already cached on the Proxmox host, it is reused

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
- either an existing cloud-init capable VM template on every Proxmox node you reference in `cluster_nodes`, or the optional `just create-templates` step
- matching `template_id` values in `cluster.tfvars` for those templates on the target nodes
- `VS Code` with the dev container is recommended so the toolchain stays consistent
- `Docker Desktop` or an equivalent container runtime for the dev container workflow

Everything else is expected to come from the dev container.

## ⚡ Quick Start

This is the shortest path to a running cluster:

```bash
just init-config
just doctor
```

Edit the two generated local files:

- `cluster.tfvars` for non-secret cluster configuration
- `cluster.secrets.tfvars` for Proxmox credentials and the shared bootstrap token

Optional: if you want this repo to create the Proxmox VM templates for you first, copy and edit:

- `00-create-template/inventory/hosts.yml.example` -> `00-create-template/inventory/hosts.yml`
- `00-create-template/vars/templates.yml.example` -> `00-create-template/vars/templates.yml`

Then run:

```bash
just create-templates
```

If the Proxmox hosts require a `become` password, run:

```bash
just create-templates true
```

The example template vars default to the official Debian Trixie generic image and one template per Proxmox node. Set the VM IDs, storage names, bridge, and SSH access for your environment before running the playbook. The inventory host names and the keys under `proxmox_templates` must match the actual Proxmox node names.

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

## 🏭 `just create-templates`

Use this optional task when you want the repo to create Debian Trixie cloud-init templates on your Proxmox nodes before provisioning the cluster VMs.

Before running it, create and edit:

- `00-create-template/inventory/hosts.yml`
- `00-create-template/vars/templates.yml`

Then run:

```bash
just create-templates
```

If Ansible should prompt for the `become` password, use:

```bash
just create-templates true
```

This task:

- downloads the official Debian Trixie genericcloud image on each Proxmox host
- downloads the official Debian Trixie generic image on each Proxmox host
- creates the VM shell with `qm create`
- imports the disk with `qm importdisk`
- enables Cloud-Init and the Proxmox guest agent flag
- converts the VM to a reusable template

It is intentionally fail-fast and aborts if the configured VM ID or template name already exists on a target Proxmox node.

For most users, this is the main reason to use the repo: you describe the cluster once, run one command, and get a Proxmox-backed HA `k3s` environment with ingress, storage, certificates, and upgrade plumbing already in place.

## 📝 Declarative Cluster Config

The cluster is described declaratively in `cluster.tfvars`.

```hcl
cluster_nodes = [
  { name = "k3s-cp-1", role = "control_plane", proxmox_node = "pve-1", template_id = 201, vm_id = 301, ip = "10.30.0.11" },
  { name = "k3s-cp-2", role = "control_plane", proxmox_node = "pve-2", template_id = 202, vm_id = 302, ip = "10.30.0.12" },
  { name = "k3s-cp-3", role = "control_plane", proxmox_node = "pve-1", template_id = 201, vm_id = 303, ip = "10.30.0.13" },
  { name = "k3s-wk-1", role = "worker", proxmox_node = "pve-2", template_id = 202, vm_id = 304, ip = "10.30.0.21" },
  { name = "k3s-wk-2", role = "worker", proxmox_node = "pve-1", template_id = 201, vm_id = 305, ip = "10.30.0.22" }
]

api_endpoint           = "10.30.0.10"
kube_vip_service_range = "10.30.0.251-10.30.0.255"
domain_suffix          = "k3s.home"
```

From that description, the repo derives:

- the Proxmox VMs to create
- the generated Ansible inventory
- the generated bootstrap values for `k3s-ansible`
- the generated cluster values consumed by Helmfile

That is the core model of this repo: describe the cluster once, derive everything else from it.

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

The `.generated/` directory contains Terraform-derived artifacts and is gitignored on purpose. Do not edit files there manually. Regenerate them with `just sync-config` or `just provision-vms`.

These generated files currently include:

- `ansible/inventory/hosts.yml`
- `.generated/bootstrap.vars.yml`
- `.generated/core.values.yaml`

If you only changed `cluster.tfvars` or `cluster.secrets.tfvars` and want to refresh generated artifacts without reprovisioning VMs, use:

```bash
just sync-config
```

## 🔧 Main Commands

- `just doctor`: run local preflight checks for tools, config files, placeholders, and generated artifacts
- `just create-templates`: optionally create Debian Trixie cloud-init templates on the configured Proxmox hosts
  Use `just create-templates true` when Ansible should prompt for the `become` password.
- `just provision-vms`: create or update the Proxmox VMs and refresh generated artifacts
- `just configure-vms`: prepare the nodes with base OS configuration and Longhorn disk setup
- `just bootstrap-cluster`: install HA `k3s` with kube-vip and merge kubeconfig locally
- `just install-core`: install the Helmfile-managed platform stack and upgrade plans
- `just verify-bootstrap`: re-run bootstrap validation
- `just verify-core`: re-run core platform validation
- `just bootstrap-cert-manager`: re-run only the cert-manager bootstrap release
- `just destroy-cluster`: destroy the Terraform-managed VM infrastructure

## 📁 Repo Layout

- [`00-create-template`](00-create-template): optional Ansible-based Proxmox template creation
- [`01-provision`](01-provision): Terraform for Proxmox VMs and generated downstream config
- [`02-configure`](02-configure): Ansible base host preparation
- [`03-bootstrap`](03-bootstrap): HA `k3s` bootstrap with `k3s-ansible`
- [`04-core`](04-core): Helmfile-managed cluster services
- [`05-examples`](05-examples): example workloads for testing the setup
