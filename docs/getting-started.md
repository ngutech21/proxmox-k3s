# Getting Started

This is the main setup flow for bringing up the homelab cluster.

## 1. Prepare your environment

- Have at least one Proxmox server available
- Use VS Code with the dev container
- Use Docker Desktop or an equivalent container runtime

The dev container provides the required tooling for this repo.

## 2. Initialize local config files

Create the local configuration files:

```bash
just init-config
```

Then set the values for:

- Proxmox access in `01-provision/terraform.tfvars`
- cluster settings in `03-bootstrap/vars/cluster.yml`
- domain and platform settings in `04-core/.env`

For `01-provision/terraform.tfvars`, first create a Proxmox API token:

1. Log in to the Proxmox web UI.
2. Open `Datacenter` -> `Permissions` -> `API Tokens`.
3. Select the user that Terraform should use, or create a dedicated one first.
4. Create a new API token.
5. Copy these values into `01-provision/terraform.tfvars`:
   - `proxmox_api_url`
   - `proxmox_api_token_id`
   - `proxmox_api_token_secret`

Example:

```hcl
proxmox_api_url          = "https://pve.lab.local:8006/api2/json"
proxmox_api_token_id     = "terraform@pve!k3s"
proxmox_api_token_secret = "REPLACE_ME"
```

Generate the shared cluster token:

```bash
just generate-cluster-token
```

Encrypt the bootstrap secret file:

```bash
just encrypt-bootstrap-secrets
```

## 3. Check local tools

```bash
just check-tools
```

## 4. Provision the VMs

```bash
just provision-vms
```

This creates or updates the Proxmox VMs and generates the Ansible inventory.

If the VMs already exist and you only need to regenerate the Ansible inventory, run:

```bash
just refresh-inventory
```

## 5. Prepare the nodes

```bash
just configure-vms
```

This installs the base OS packages and k3s prerequisites.

## 6. Bootstrap the cluster

```bash
just bootstrap-cluster
```

This installs the HA `k3s` cluster with `kube-vip`.

## 7. Install core platform services

```bash
just install-core
```

This installs the main in-cluster services, including:

- Traefik
- Longhorn
- CloudNativePG operator
- cert-manager
- system-upgrade-controller

## 8. Optional example workloads

After the platform is ready, you can deploy sample workloads from [`05-examples`](../05-examples).

## Order Summary

1. Run `just init-config`
2. Run `just generate-cluster-token`
3. Run `just encrypt-bootstrap-secrets`
4. Run `just check-tools`
5. Run `just provision-vms`
6. Run `just configure-vms`
7. Run `just bootstrap-cluster`
8. Run `just install-core`
