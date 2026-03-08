# 04-core

Helmfile-managed platform applications for the k3s cluster.

## Managed components

1. cert-manager (with CRDs)
2. system-upgrade-controller
3. Traefik ingress controller (LoadBalancer)
4. metrics-server (built into k3s)
5. Longhorn storage

## Prerequisites

- Cluster bootstrap complete: `03-bootstrap`
- `kubectl` context points to your k3s cluster
- generated Helmfile state values at `.generated/core.values.yaml`

## Configuration model

`04-core` has no manually maintained `.env` workflow anymore.

Core values are generated from Terraform inputs in `cluster.tfvars` by running:

```bash
just provision-vms
```

`just sync-config` remains available if you only want to refresh generated files without reprovisioning VMs.

Helmfile receives cluster values with `--state-values-file ../.generated/core.values.yaml`.

## Install/upgrade platform apps

From the repository root:

```bash
just install-core
```

This task uses the generated values from the latest Terraform apply, installs Helm-managed components, and applies the k3s upgrade plans.

To re-run checks without reinstalling:

```bash
just verify-core
```

## Optional: Bootstrap cert-manager issuers only

```bash
just bootstrap-cert-manager
```

## Optional: Protect Longhorn UI with BasicAuth

```bash
LONGHORN_USER=admin LONGHORN_PASS='CHANGE_ME_STRONG_PASSWORD' just enable-longhorn-auth
```

## Notes

- Longhorn host is derived as `longhorn.<domain_suffix>`.
- Smoke-test host is derived as `smoke.<domain_suffix>`.
- cert-manager issuer and secret naming is fixed by convention in generated values.
