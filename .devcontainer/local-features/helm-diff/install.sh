#!/usr/bin/env bash
set -euo pipefail

export HELM_PLUGINS="${HELM_PLUGINS:-/usr/local/share/helm/plugins}"
mkdir -p "${HELM_PLUGINS}"

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required before installing the helm-diff plugin." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends git ca-certificates
  rm -rf /var/lib/apt/lists/*
fi

if helm plugin list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx diff; then
  echo "helm-diff is already installed."
  exit 0
fi

helm plugin install --verify=false https://github.com/databus23/helm-diff
