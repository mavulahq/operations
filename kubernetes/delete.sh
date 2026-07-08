#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=$(cd "$(dirname "$0")" && pwd)

kubectl delete -f "$BASE_DIR/secrets-external.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/monitoring-workbench.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/monitoring-ledger-core.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/service-workbench.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/service-ledger-core.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/deployment-workbench.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/deployment-ledger-core.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/workbench-secret.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/ledger-core-secret.yaml" --ignore-not-found
kubectl delete -f "$BASE_DIR/namespace.yaml" --ignore-not-found
