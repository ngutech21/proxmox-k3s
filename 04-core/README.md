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
- `helm`, `helmfile`, and `kubectl` installed on control machine

## Install/upgrade platform apps

```bash
cd 04-core
cp .env.example .env
just install-core
```

`just` loads `04-core/.env` automatically. Use `.env.example` as the starting point for domain and issuer naming. `LONGHORN_HOST` and `CERT_MANAGER_SMOKE_HOST` can be omitted to derive them from `DOMAIN_SUFFIX`.

`install-core` installs the Helm-managed components, including the cert-manager issuer chain, and applies the k3s upgrade plans. It does not enable Longhorn auth.

To re-run the standard platform checks without reinstalling anything:

```bash
just verify-core
```

## Optional: Bootstrap cert-manager issuers

Use the dedicated `just` task:

```bash
just bootstrap-cert-manager
```

This reapplies the Helmfile-managed cert-manager bootstrap release using the values from `04-core/.env`.

Set `CERT_MANAGER_ENABLE_SMOKE_TEST=true` in `.env` if you also want the smoke test certificate created by Helmfile.

## Bootstrap system-upgrade-controller plans

Apply the Plan CRD and plan resources:

```bash
kubectl apply -f manifests/system-upgrade/00-crd.yaml
kubectl apply -f manifests/system-upgrade/10-server-plan.yaml
kubectl apply -f manifests/system-upgrade/11-agent-plan.yaml
```

To upgrade k3s later, edit `version:` in both plan files and re-apply.

By default, the Longhorn UI is installed without authentication so `install-core` completes without any extra input.

## Optional: Protect Longhorn UI with BasicAuth

Enable auth with the dedicated `just` task:

```bash
LONGHORN_USER=admin LONGHORN_PASS='CHANGE_ME_STRONG_PASSWORD' just enable-longhorn-auth
```

This task:

- creates the `longhorn-basic-auth` secret
- applies the Traefik middleware from `manifests/longhorn/00-middleware-basic-auth.yaml`
- annotates the `longhorn-ingress` with the required middleware reference

Note:

- `htpasswd` must be installed on the control machine
- a later `helmfile apply` may remove the manual ingress annotation, so rerun `just enable-longhorn-auth` after reapplying Longhorn

## Verification

### 1) Traefik

```bash
kubectl -n traefik get svc
kubectl -n traefik get svc traefik
kubectl get ingressclass
```

Expected:

- `traefik` service has an external IP from kube-vip range (`192.168.178.251-255`)
- `traefik` ingress class exists and is default

### 2) system-upgrade-controller

```bash
kubectl -n cattle-system get deploy,pods | grep system-upgrade-controller
kubectl -n cattle-system get plans.upgrade.cattle.io
```

Expected:

- `system-upgrade-controller` deployment is `Available`
- `k3s-server-plan` and `k3s-agent-plan` exist

### 3) Longhorn

```bash
kubectl -n longhorn-system get pods
kubectl -n longhorn-system get ingress
kubectl get sc
```

Expected:

- Longhorn pods are `Running`
- Longhorn UI ingress host matches `LONGHORN_HOST` from `.env`
- Longhorn storage class is available

### 4) metrics-server

```bash
kubectl -n kube-system get deploy metrics-server
kubectl top nodes
kubectl top pods -A
```

Expected:

- `metrics-server` deployment is `Available`
- `kubectl top` returns CPU and memory metrics for nodes and pods

### 5) cert-manager

```bash
kubectl -n cert-manager get pods
kubectl get clusterissuer
kubectl -n default get certificate cert-manager-smoke-test
kubectl -n default describe certificate cert-manager-smoke-test
```

Expected:

- cert-manager pods are `Running`
- issuers named by `CERT_MANAGER_SELFSIGNED_ISSUER` and `CERT_MANAGER_CA_ISSUER` are `Ready`
- if enabled, the smoke-test certificate becomes `Ready`

## Notes

- Traefik is installed here (not in bootstrap stage), so ingress resources remain inactive until this step is complete.
- MetalLB is intentionally omitted because kube-vip handles `LoadBalancer` service IP allocation.
- `metrics-server` is provided by k3s as a packaged component unless explicitly disabled.
- system-upgrade-controller plans are namespace-scoped and are intentionally stored in `cattle-system` to match the Helm chart defaults.
