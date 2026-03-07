# 03-bootstrap

Bootstrap k3s with `k3s-ansible` and pre-stage kube-vip manifests.

## Prerequisites

- VMs provisioned via `01-provision`
- Base prep completed via `02-configure/playbooks/base-prep.yml`
- Inventory present at `ansible/inventory/hosts.yml`

## Prepare bootstrap vars

```bash
cd 03-bootstrap
cp vars/cluster.yml.example vars/cluster.yml
cp vars/secret.vault.yml.example vars/secret.vault.yml
```

Set in `vars/cluster.yml`:

- `k3s_version` (required, no default)
- `api_endpoint` (default `192.168.178.10`)
- `kube_vip_service_range` (default `192.168.178.251-192.168.178.255`)

Set in `vars/secret.vault.yml`:

- `token` (strong shared cluster token)

Generate a strong token, for example:

```bash
openssl rand -hex 32
```

Encrypt secret vars:

```bash
ansible-vault encrypt vars/secret.vault.yml
```

## Run bootstrap

```bash
just bootstrap-cluster
```

The `just` task prompts once for your vault password and reuses it for both bootstrap steps.

This stage:

1. Installs pinned `k3s-ansible` collection from `requirements.yml`.
2. Pre-stages kube-vip manifests into `/var/lib/rancher/k3s/server/manifests` on all server nodes.
3. Runs `k3s.orchestration.site` to install HA k3s.
4. Installs without bundled Traefik/servicelb.

After this step, cluster is up and reachable via kube-vip API VIP. Ingress is intentionally not installed yet (comes in `04-core`).
