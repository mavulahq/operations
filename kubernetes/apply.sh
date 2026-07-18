#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=$(cd "$(dirname "$0")" && pwd)

kubectl apply -f "$BASE_DIR/namespace.yaml"
if [ "${APPLY_EXTERNAL_SECRETS:-false}" = "true" ]; then
  kubectl apply -f "$BASE_DIR/secrets-external.yaml"
else
  for secret_name in identity-access-secrets ledger-core-secrets ledger-core-metrics-secrets workbench-secrets workbench-metrics-secrets; do
    kubectl get secret "$secret_name" -n mavula >/dev/null 2>&1 || {
      echo "$secret_name is required; provision it before applying runtime deployments" >&2
      exit 1
    }
  done
fi
kubectl apply -f "$BASE_DIR/deployment-identity-access.yaml"
kubectl apply -f "$BASE_DIR/deployment-ledger-core.yaml"
kubectl apply -f "$BASE_DIR/deployment-workbench.yaml"
kubectl apply -f "$BASE_DIR/service-identity-access.yaml"
kubectl apply -f "$BASE_DIR/service-ledger-core.yaml"
kubectl apply -f "$BASE_DIR/service-workbench.yaml"
kubectl apply -f "$BASE_DIR/monitoring-ledger-core.yaml"
kubectl apply -f "$BASE_DIR/monitoring-workbench.yaml"
