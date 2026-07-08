#!/usr/bin/env bash
# mavula.io - Secrets Management & Vault Integration
# Copyright (c) 2026 mavula.io
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

NAMESPACE=${NAMESPACE:-mavula}
AWS_REGION=${AWS_REGION:-eu-west-1}
ENVIRONMENT=${ENVIRONMENT:-staging}

echo "Setting up secrets management for namespace: $NAMESPACE"

# Create ServiceAccount for External Secrets operator
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: $NAMESPACE
---
apiVersion: iam.cnpg.io/v1
kind: IAMRole
metadata:
  name: external-secrets-role
  namespace: $NAMESPACE
spec:
  assetNames:
    - secretsmanager:GetSecretValue
    - secretsmanager:DescribeSecret
  resources:
    - 'arn:aws:secretsmanager:$AWS_REGION:*:secret:mavula/*'
EOF

# Create External Secrets objects
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: $NAMESPACE
spec:
  provider:
    aws:
      service: SecretsManager
      region: $AWS_REGION
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ledger-core-secrets
  namespace: $NAMESPACE
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: ledger-core-secrets
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: mavula/ledger-core/database_url
    - secretKey: JWT_SECRET
      remoteRef:
        key: mavula/ledger-core/jwt_secret
    - secretKey: REDIS_URL
      remoteRef:
        key: mavula/redis_url
    - secretKey: COOKIE_DOMAIN
      remoteRef:
        key: mavula/cookie_domain
    - secretKey: INTERNAL_API_KEY
      remoteRef:
        key: mavula/internal_api_key
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: workbench-secrets
  namespace: $NAMESPACE
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: workbench-secrets
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: mavula/ledger-core/database_url
    - secretKey: REDIS_URL
      remoteRef:
        key: mavula/redis_url
    - secretKey: INTERNAL_API_KEY
      remoteRef:
        key: mavula/internal_api_key
EOF

echo "Secrets management configured. Verify in AWS Secrets Manager and k8s:"
echo "  aws secretsmanager list-secrets --region $AWS_REGION --filters Key=name,Values=mavula"
echo "  kubectl get secret -n $NAMESPACE ledger-core-secrets workbench-secrets"
