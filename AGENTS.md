# AGENTS.md

## Repo Purpose

This repo builds a homelab HA `k3s` cluster on Proxmox VMs.

## Main Stack

- `Proxmox` for virtualization
- `Terraform` for VM provisioning
- `Ansible` for host prep and cluster bootstrap
- `Helm` and `Helmfile` for Kubernetes platform services

## Installed Core Services

- `Traefik` for ingress
- `Longhorn` for storage
- `CloudNativePG` operator for PostgreSQL

## Repo Stages

- `01-provision`: create Proxmox VMs
- `02-configure`: prepare nodes
- `03-bootstrap`: install HA `k3s`
- `04-core`: install platform services
- `05-examples`: sample workloads

## Working Notes

- Prefer running from a VS Code dev container.
- Use [`justfile`](/Users/steffen/projects/proxmox-k3s/justfile) as the main workflow entrypoint.
