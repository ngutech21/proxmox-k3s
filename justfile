ansible_config := "ansible/ansible.cfg"
bootstrap_dir := "03-bootstrap"
bootstrap_requirements := bootstrap_dir + "/requirements.yml"
bootstrap_stage_playbook := bootstrap_dir + "/playbooks/bootstrap.yml"
bootstrap_site_playbook := bootstrap_dir + "/playbooks/site-serial.yml"
terraform_dir := "01-provision"
terraform_var_file := "../cluster.tfvars"
terraform_secret_var_file := "../cluster.secrets.tfvars"
cluster_config := "cluster.tfvars"
cluster_config_example := "cluster.tfvars.example"
cluster_secrets := "cluster.secrets.tfvars"
cluster_secrets_example := "cluster.secrets.tfvars.example"
generated_bootstrap_vars := ".generated/bootstrap.vars.yml"
generated_core_values := ".generated/core.values.yaml"

# prints this help
default:
    @just --list

# Verify that the required local CLI tools are installed before running the workflow.
check-tools:
    #!/usr/bin/env bash
    set -euo pipefail

    required_commands=(
      terraform
      ansible
      ansible-playbook
      ansible-galaxy
      kubectl
      helm
      helmfile
    )

    missing=()
    for cmd in "${required_commands[@]}"; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
      fi
    done

    
    if ! helm plugin list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx diff; then
      missing+=("helm-diff plugin")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
      echo "Missing required tools:" >&2
      printf ' - %s\n' "${missing[@]}" >&2
      if printf '%s\n' "${missing[@]}" | grep -qx "helm-diff plugin"; then
        echo >&2
        echo "Install helm-diff with:" >&2
        echo "  helm plugin install https://github.com/databus23/helm-diff" >&2
      fi
      exit 1
    fi

    echo "All required tools are installed."

# Initialize missing local config files from the checked-in examples.
init-config:
    #!/usr/bin/env bash
    set -euo pipefail

    init_from_example() {
      local target="$1"
      local example="$2"

      if [[ -f "$target" ]]; then
        echo "Keeping existing $target"
        return
      fi

      cp "$example" "$target"
      echo "Created $target from $example"
    }

    init_from_example "{{ cluster_config }}" "{{ cluster_config_example }}"
    init_from_example "{{ cluster_secrets }}" "{{ cluster_secrets_example }}"

# Generate all derived artifacts from Terraform inputs.
[working-directory("01-provision")]
sync-config:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ ! -f "{{ terraform_var_file }}" ]]; then
      echo "Missing {{ cluster_config }} (run 'just init-config' first)." >&2
      exit 1
    fi

    if [[ ! -f "{{ terraform_secret_var_file }}" ]]; then
      echo "Missing {{ cluster_secrets }} (run 'just init-config' first)." >&2
      exit 1
    fi

    mkdir -p ../.generated

    terraform init
    terraform apply \
      -var-file="{{ terraform_var_file }}" \
      -var-file="{{ terraform_secret_var_file }}" \
      -target=local_file.ansible_inventory \
      -target=local_file.bootstrap_vars \
      -target=local_file.core_values

# Provision or update the Proxmox VMs defined in Terraform.
[working-directory("01-provision")]
provision-vms: check-tools
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ ! -f "{{ terraform_var_file }}" ]]; then
      echo "Missing {{ cluster_config }} (run 'just init-config' first)." >&2
      exit 1
    fi

    if [[ ! -f "{{ terraform_secret_var_file }}" ]]; then
      echo "Missing {{ cluster_secrets }} (run 'just init-config' first)." >&2
      exit 1
    fi

    mkdir -p ../.generated

    terraform init
    terraform apply \
      -var-file="{{ terraform_var_file }}" \
      -var-file="{{ terraform_secret_var_file }}"

# Prepare all cluster nodes with base packages, Longhorn disk setup, and k3s prerequisites.
configure-vms:
    ANSIBLE_CONFIG={{ ansible_config }} ansible-playbook 02-configure/playbooks/base-prep.yml

# Install the k3s-ansible collection, pre-stage kube-vip, and bootstrap the HA k3s cluster.
bootstrap-cluster:
    #!/usr/bin/env bash
    set -euo pipefail
    export ANSIBLE_CONFIG="{{ ansible_config }}"

    if [[ ! -f "{{ generated_bootstrap_vars }}" ]]; then
      echo "Missing {{ generated_bootstrap_vars }}. Run 'just provision-vms' or 'just sync-config' first." >&2
      exit 1
    fi

    token="$(sed -nE 's/^[[:space:]]*cluster_bootstrap_token[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' {{ cluster_secrets }} | head -n1)"
    if [[ -z "$token" ]]; then
      echo "cluster_bootstrap_token is missing in {{ cluster_secrets }}." >&2
      exit 1
    fi

    mkdir -p "$HOME/.kube"

    ansible-galaxy collection install -r "{{ bootstrap_requirements }}"
    ansible-playbook "{{ bootstrap_stage_playbook }}" -e @"{{ generated_bootstrap_vars }}" -e "token=$token"
    ansible-playbook "{{ bootstrap_site_playbook }}" -e @"{{ generated_bootstrap_vars }}" -e "token=$token"
    just verify-bootstrap

# Re-run the bootstrap validation checks against the current cluster state.
verify-bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    export ANSIBLE_CONFIG="{{ ansible_config }}"

    if [[ ! -f "{{ generated_bootstrap_vars }}" ]]; then
      echo "Missing {{ generated_bootstrap_vars }}. Run 'just provision-vms' or 'just sync-config' first." >&2
      exit 1
    fi

    if [[ ! -f "{{ cluster_secrets }}" ]]; then
      echo "Missing {{ cluster_secrets }} (run 'just init-config' first)." >&2
      exit 1
    fi

    token="$(sed -nE 's/^[[:space:]]*cluster_bootstrap_token[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' {{ cluster_secrets }} | head -n1)"
    if [[ -z "$token" ]]; then
      echo "cluster_bootstrap_token is missing in {{ cluster_secrets }}." >&2
      exit 1
    fi

    mkdir -p "$HOME/.kube"

    ansible-playbook "{{ bootstrap_site_playbook }}" -e @"{{ generated_bootstrap_vars }}" -e "token=$token"

# Install or update core cluster services managed by Helmfile and apply upgrade plans.
[working-directory("04-core")]
install-core: check-tools
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ ! -f "../{{ generated_core_values }}" ]]; then
      echo "Missing {{ generated_core_values }}. Run 'just provision-vms' or 'just sync-config' first." >&2
      exit 1
    fi

    helmfile --state-values-file ../{{ generated_core_values }} deps
    helmfile --state-values-file ../{{ generated_core_values }} apply
    kubectl apply -f manifests/system-upgrade/00-crd.yaml
    kubectl apply -f manifests/system-upgrade/10-server-plan.yaml
    kubectl apply -f manifests/system-upgrade/11-agent-plan.yaml
    just verify-core

# Re-run the core platform validation checks against the current cluster state.
[working-directory("04-core")]
verify-core:
    #!/usr/bin/env bash
    set -euo pipefail

    kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s
    kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s
    kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s

    kubectl -n cattle-system rollout status deploy/system-upgrade-controller --timeout=180s
    kubectl -n cattle-system get plans.upgrade.cattle.io k3s-server-plan k3s-agent-plan >/dev/null

    kubectl -n traefik rollout status deploy/traefik --timeout=180s
    kubectl get ingressclass traefik >/dev/null
    test -n "$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

    kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer --timeout=180s
    kubectl -n longhorn-system rollout status deploy/longhorn-ui --timeout=180s
    kubectl -n longhorn-system rollout status daemonset/longhorn-manager --timeout=180s
    kubectl -n longhorn-system get ingress longhorn-ingress >/dev/null
    kubectl get sc longhorn >/dev/null

    kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
    kubectl top nodes >/dev/null

# Bootstrap the cert-manager issuer chain after cert-manager itself is installed and ready.
[working-directory("04-core")]
bootstrap-cert-manager: check-tools
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -f "../{{ generated_core_values }}" ]]; then
      echo "Missing {{ generated_core_values }}. Run 'just provision-vms' or 'just sync-config' first." >&2
      exit 1
    fi
    helmfile --state-values-file ../{{ generated_core_values }} apply -l app=cert-manager-bootstrap

# Protect the Longhorn UI with Traefik BasicAuth using LONGHORN_USER and LONGHORN_PASS.
[working-directory("04-core")]
enable-longhorn-auth:
    #!/usr/bin/env bash
    set -euo pipefail

    LONGHORN_USER="${LONGHORN_USER:-admin}"
    LONGHORN_PASS="${LONGHORN_PASS:-}"

    if [[ -z "$LONGHORN_PASS" ]]; then
      echo "Missing LONGHORN_PASS environment variable." >&2
      echo "Example: LONGHORN_USER=admin LONGHORN_PASS='strong-password' just enable-longhorn-auth" >&2
      exit 1
    fi

    if ! command -v htpasswd >/dev/null 2>&1; then
      echo "htpasswd command not found. Install apache2-utils (Debian) or httpd-tools (RHEL/macOS package equivalent)." >&2
      exit 1
    fi

    LONGHORN_HTPASSWD="$(htpasswd -nbB "$LONGHORN_USER" "$LONGHORN_PASS" | sed -e 's/\\$/\\$\\$/g')"
    kubectl -n longhorn-system create secret generic longhorn-basic-auth \
      --from-literal=users="$LONGHORN_HTPASSWD" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f manifests/longhorn/00-middleware-basic-auth.yaml
    kubectl -n longhorn-system annotate ingress longhorn-ingress \
      traefik.ingress.kubernetes.io/router.middlewares=longhorn-system-longhorn-auth@kubernetescrd \
      --overwrite

# Re-apply the k3s server and agent upgrade plans after changing the target version.
[working-directory("04-core")]
upgrade-cluster:
    kubectl apply -f manifests/system-upgrade/10-server-plan.yaml
    kubectl apply -f manifests/system-upgrade/11-agent-plan.yaml

# Reboot all cluster nodes one by one and wait for each node to return.
restart-nodes:
    ANSIBLE_CONFIG={{ ansible_config }} ansible-playbook 02-configure/playbooks/restart-nodes.yml
