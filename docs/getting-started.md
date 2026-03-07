# Getting Started

This guide describes the current workflow where **all downstream config artifacts are generated from Terraform inputs**.

## 1. Prepare your environment

- Have at least one Proxmox server available.
- Use VS Code with the dev container.
- Use Docker Desktop or an equivalent container runtime.

The dev container provides the required tooling for this repo.

## 2. Initialize local config files

Create local config files from the examples:

```bash
just init-config
```

Then edit only these two source files:

- `cluster.tfvars` for non-secret cluster configuration.
- `cluster.secrets.tfvars` for local secrets.

> Treat these files as the single source of truth for environment-specific settings.

## 3. Generate derived config from Terraform

Generate all derived artifacts from `cluster.tfvars` + `cluster.secrets.tfvars`:

```bash
just sync-config
```

This runs Terraform in `01-provision` and writes generated files used by Ansible and Helmfile.

## 4. Check local tools

```bash
just check-tools
```

## 5. Provision VMs

```bash
just provision-vms
```

This creates or updates Proxmox VMs and applies Terraform state changes.

## 6. Prepare nodes

```bash
just configure-vms
```

## 7. Bootstrap k3s

```bash
just bootstrap-cluster
```

This command runs `just sync-config` first, then bootstraps using generated bootstrap vars and the token from `cluster.secrets.tfvars`.

## 8. Install core platform services

```bash
just install-core
```

This command runs `just sync-config` first and applies Helmfile with generated cluster values.

## Generated files (do not edit manually)

The following files are generated from Terraform and should never be edited manually:

- `ansible/inventory/hosts.yml`
- `.generated/bootstrap.vars.yml`
- `.generated/core.values.yaml`

If you change `cluster.tfvars` or `cluster.secrets.tfvars`, re-run:

```bash
just sync-config
```

## Recommended order

1. `just init-config`
2. fill `cluster.tfvars` and `cluster.secrets.tfvars`
3. `just sync-config`
4. `just check-tools`
5. `just provision-vms`
6. `just configure-vms`
7. `just bootstrap-cluster`
8. `just install-core`
