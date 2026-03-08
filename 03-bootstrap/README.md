# 03-bootstrap

Bootstrap k3s with `k3s-ansible` and pre-stage kube-vip manifests.

## Prerequisites

- VMs provisioned via `01-provision`
- Base prep completed via `02-configure/playbooks/base-prep.yml`
- Generated inventory at `ansible/inventory/hosts.yml`
- Generated bootstrap vars at `.generated/bootstrap.vars.yml`

## Configuration model

`03-bootstrap` has no manually maintained stage config files.

All bootstrap variables are generated from Terraform inputs in `cluster.tfvars` by running:

```bash
just provision-vms
```

`just sync-config` remains available if you only want to refresh generated files without reprovisioning VMs.

The bootstrap token is read from `cluster.secrets.tfvars` and passed as an extra var by `just bootstrap-cluster`.

## Bootstrap the cluster

From the repository root:

```bash
just bootstrap-cluster
```

What this does:

1. Uses generated bootstrap vars from the latest Terraform apply.
2. Installs the `k3s.orchestration` collection.
3. Pre-stages kube-vip manifests on all server nodes.
4. Runs `k3s.orchestration.site` to install HA k3s.
5. Installs without bundled Traefik/servicelb.

After this step, the cluster is up and reachable via the kube-vip API endpoint.
Ingress is intentionally installed later in `04-core`.
