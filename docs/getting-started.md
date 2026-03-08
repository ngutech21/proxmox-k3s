# Getting Started

This is the main setup flow for bringing up the homelab cluster with a Terraform-first configuration model.

## 1. Prepare your environment

- Have at least one Proxmox server available
- Use VS Code with the dev container
- Use Docker Desktop or an equivalent container runtime

The dev container provides the required tooling for this repo.

## 2. Optional: check local tools

```bash
just check-tools
```

`just provision-vms` runs this automatically, but the standalone check is still useful if you want to validate the environment first.


## 3. Initialize the two local config files

Create local config files:

```bash
just init-config
```

Then edit only:

- `cluster.tfvars` for non-secret cluster configuration
- `cluster.secrets.tfvars` for local secrets

`cluster.tfvars` includes:

- Proxmox URL and TLS mode
- node layout and VM defaults
- `k3s_version`
- `api_endpoint`
- `kube_vip_service_range`
- `domain_suffix`
- `cert_manager_enable_smoke_test`

`cluster.secrets.tfvars` includes:

- `proxmox_api_token_id`
- `proxmox_api_token_secret`
- `cluster_bootstrap_token`


## 4. Provision VMs

```bash
just provision-vms
```

This creates or updates the Proxmox VMs and refreshes the generated inventory and stage values.

## 5. Prepare nodes

```bash
just configure-vms
```

Run this directly after `just provision-vms`. It installs the required OS packages and prepares the nodes for k3s.

## 6. Bootstrap k3s

```bash
just bootstrap-cluster
```

This uses the generated bootstrap vars from the latest Terraform apply and the token from `cluster.secrets.tfvars`.

## 7. Install core platform services

```bash
just install-core
```

This applies Helmfile using generated cluster values from the latest Terraform apply.

## Optional: refresh generated files only

```bash
just sync-config
```

Use this when you changed `cluster.tfvars` or `cluster.secrets.tfvars` and only want to refresh generated artifacts without reprovisioning VMs.

## Generated files

The following files are derived artifacts and should never be edited manually:

- `ansible/inventory/hosts.yml`
- `.generated/bootstrap.vars.yml`
- `.generated/core.values.yaml`

## Order Summary

1. `just init-config`
2. fill `cluster.tfvars` and `cluster.secrets.tfvars`
3. `just provision-vms`
4. `just configure-vms`
5. `just bootstrap-cluster`
6. `just install-core`
