#!/usr/bin/env bash
# mavula.io - External Secrets bootstrap
# Copyright (c) 2026 mavula.io
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
NAMESPACE=${NAMESPACE:-mavula}
AWS_REGION=${AWS_REGION:-eu-west-1}

[[ "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || { echo "Invalid NAMESPACE" >&2; exit 1; }
[[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]] || { echo "Invalid AWS_REGION" >&2; exit 1; }

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: $NAMESPACE
EOF
sed -e "s/namespace: mavula/namespace: $NAMESPACE/g" \
    -e "s/region: eu-west-1/region: $AWS_REGION/g" \
    "$ROOT_DIR/kubernetes/secrets-external.yaml" | kubectl apply -f -

echo "External Secrets resources configured for namespace $NAMESPACE."
echo "Verify managed values and workload identity before deploying runtime services."
