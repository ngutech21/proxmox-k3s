# proxmox-k3s

[![Terraform](https://img.shields.io/github/actions/workflow/status/ngutech21/proxmox-k3s/terraform.yml?branch=master&label=Terraform)](https://github.com/ngutech21/proxmox-k3s/actions/workflows/terraform.yml)
[![Ansible](https://img.shields.io/github/actions/workflow/status/ngutech21/proxmox-k3s/ansible.yml?branch=master&label=Ansible)](https://github.com/ngutech21/proxmox-k3s/actions/workflows/ansible.yml)
[![Actionlint](https://img.shields.io/github/actions/workflow/status/ngutech21/proxmox-k3s/actionlint.yml?branch=master&label=Actionlint)](https://github.com/ngutech21/proxmox-k3s/actions/workflows/actionlint.yml)

Small homelab stack for running a highly available `k3s` cluster on top of Proxmox VMs.

## Architecture

The basic flow is:

1. Proxmox provides the virtualization layer.
2. Terraform creates the VM infrastructure and inventory data.
3. Ansible prepares the nodes and bootstraps the `k3s` cluster.
4. Helmfile installs the core platform services into Kubernetes using Helm charts.

This keeps the homelab setup split into clear stages: provision the machines, configure the OS, bootstrap Kubernetes, then install cluster services.

## Technologies

- `Proxmox`: hypervisor and VM platform
- `Terraform`: VM provisioning and inventory generation
- `Ansible`: node preparation and cluster bootstrap
- `Helm`: package manager for Kubernetes applications
- `Helmfile`: orchestration layer for repeatable Helm releases

## Prerequisites

- At least one `Proxmox` server
- One or more cluster nodes; multiple nodes are supported but not required
- `VS Code` is recommended for the dev container workflow
- `Docker Desktop` or an equivalent container runtime for running the dev container

Everything else needed for the workflow should be provided by the dev container.

Core services in this repo include Traefik for ingress, Longhorn for distributed storage, the CloudNativePG operator for PostgreSQL, certificate management, upgrade management, and example workloads.

## Repo Layout

- [`01-provision`](01-provision): Terraform for Proxmox VMs
- [`02-configure`](02-configure): Ansible base host preparation
- [`03-bootstrap`](03-bootstrap): `k3s` cluster bootstrap
- [`04-core`](04-core): Helmfile-managed platform services
- [`05-examples`](05-examples): example workloads for testing the setup

## Recommended Usage

This repo is best used from a VS Code dev container so tools like `terraform`, `ansible`, `helm`, `helmfile`, and `kubectl` stay consistent across machines.

The main workflow is exposed through the [`justfile`](justfile).

The user-edited local inputs are intentionally reduced to two gitignored files in the repository root:

- `cluster.tfvars` for non-secret cluster configuration
- `cluster.secrets.tfvars` for local secrets

Terraform uses those inputs to generate the downstream inventory and stage values consumed by Ansible and Helmfile.

The standard setup flow is:

1. `just init-config`
2. `just provision-vms`
3. `just bootstrap-cluster`
4. `just install-core`

For the step-by-step setup order, start with [`docs/getting-started.md`](docs/getting-started.md).
