#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=$(cd "$(dirname "$0")" && pwd)

kubectl apply -f "$BASE_DIR/namespace.yaml"
kubectl apply -f "$BASE_DIR/ledger-core-secret.yaml"
kubectl apply -f "$BASE_DIR/workbench-secret.yaml"
kubectl apply -f "$BASE_DIR/deployment-ledger-core.yaml"
kubectl apply -f "$BASE_DIR/deployment-workbench.yaml"
kubectl apply -f "$BASE_DIR/service-ledger-core.yaml"
kubectl apply -f "$BASE_DIR/service-workbench.yaml"
kubectl apply -f "$BASE_DIR/monitoring-ledger-core.yaml"
kubectl apply -f "$BASE_DIR/monitoring-workbench.yaml"
kubectl apply -f "$BASE_DIR/secrets-external.yaml"
