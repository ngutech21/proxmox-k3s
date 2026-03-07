# proxmox-k3s

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

Core services in this repo include Traefik for ingress, Longhorn for distributed storage, the CloudNativePG operator for PostgreSQL, certificate management, upgrade management, and example workloads.

## Repo Layout

- [`01-provision`](/Users/steffen/projects/proxmox-k3s/01-provision): Terraform for Proxmox VMs
- [`02-configure`](/Users/steffen/projects/proxmox-k3s/02-configure): Ansible base host preparation
- [`03-bootstrap`](/Users/steffen/projects/proxmox-k3s/03-bootstrap): `k3s` cluster bootstrap
- [`04-core`](/Users/steffen/projects/proxmox-k3s/04-core): Helmfile-managed platform services
- [`05-examples`](/Users/steffen/projects/proxmox-k3s/05-examples): example workloads for testing the setup

## Recommended Usage

This repo is best used from a VS Code dev container so tools like `terraform`, `ansible`, `helm`, `helmfile`, and `kubectl` stay consistent across machines.

The main workflow is exposed through the [`justfile`](/Users/steffen/projects/proxmox-k3s/justfile).
