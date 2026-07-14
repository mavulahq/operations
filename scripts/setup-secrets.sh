#!/usr/bin/env bash
# mavula.io - External Secrets bootstrap
# Copyright (c) 2026 mavula.io
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
NAMESPACE=${NAMESPACE:-mavula}

kubectl apply -f "$ROOT_DIR/kubernetes/namespace.yaml"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: $NAMESPACE
EOF
kubectl apply -f "$ROOT_DIR/kubernetes/secrets-external.yaml"

echo "External Secrets resources configured for namespace $NAMESPACE."
echo "Verify managed values and workload identity before deploying runtime services."
