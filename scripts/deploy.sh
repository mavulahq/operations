#!/usr/bin/env bash
# mavula.io - Deployment & Infrastructure
# Copyright (c) 2026 mavula.io
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
KUBE_CONTEXT=${KUBE_CONTEXT:-}
APPLY_EXTERNAL_SECRETS=${APPLY_EXTERNAL_SECRETS:-false}
APPLY_MONITORING=${APPLY_MONITORING:-false}

KUBECTL=(kubectl)
if [ -n "$KUBE_CONTEXT" ]; then
  KUBECTL+=(--context "$KUBE_CONTEXT")
fi

"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/namespace.yaml"

if [ "$APPLY_EXTERNAL_SECRETS" = "true" ]; then
  "${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/secrets-external.yaml"
else
  for secret_name in identity-access-secrets ledger-core-secrets workbench-secrets; do
    if ! "${KUBECTL[@]}" get secret "$secret_name" -n mavula >/dev/null 2>&1; then
      echo "Warning: $secret_name not found. Run scripts/setup-secrets.sh or set APPLY_EXTERNAL_SECRETS=true."
    fi
  done
fi

"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/service-identity-access.yaml"
"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/service-ledger-core.yaml"
"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/service-workbench.yaml"
"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/deployment-identity-access.yaml"
"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/deployment-ledger-core.yaml"
"${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/deployment-workbench.yaml"

if [ "$APPLY_MONITORING" = "true" ]; then
  "${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/monitoring-ledger-core.yaml"
  "${KUBECTL[@]}" apply -f "$ROOT_DIR/kubernetes/monitoring-workbench.yaml"
fi

echo "Kubernetes manifests applied. To provision cloud infra, run:"
echo "  cd terraform && terraform init && terraform apply"
