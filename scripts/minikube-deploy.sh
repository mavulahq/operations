#!/usr/bin/env bash
# mavula.io - Local Minikube deployment
# Copyright (c) 2026 mavula.io
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../.." && pwd)
ENV_FILE=${MAVULA_ENV_FILE:-"$ROOT_DIR/.env"}
PROFILE=${MINIKUBE_PROFILE:?set MINIKUBE_PROFILE to an existing local profile}
CONTEXT=$PROFILE
NAMESPACE=mavula
IMAGE_TAG=${MINIKUBE_IMAGE_TAG:-minikube}
REBUILD_IMAGES=${MINIKUBE_REBUILD_IMAGES:-false}
LOAD_IMAGES=${MINIKUBE_LOAD_IMAGES:-false}
DATABASE_PORT=${MINIKUBE_DATABASE_PORT:-15433}

for command_name in minikube kubectl docker pnpm; do
  command -v "$command_name" >/dev/null || { echo "$command_name is required" >&2; exit 1; }
done

if [ ! -f "$ENV_FILE" ]; then
  echo "Local configuration is required at $ENV_FILE. Start from .env.example; .env remains untracked." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required=(
  IDENTITY_DATABASE_URL IDENTITY_ISSUER IDENTITY_JWKS_JSON IDENTITY_COOKIE_KEYS
  LEDGER_CORE_DATABASE_URL LEDGER_CORE_DATABASE_ROLE_PASSWORD OIDC_AUTHORIZATION_ENDPOINT OIDC_JWKS_URI
  WORKBENCH_DATABASE_URL WORKBENCH_DATABASE_ROLE_PASSWORD SETTLEMENTS_DATABASE_URL
  WORKBENCH_OIDC_CLIENT_ID WORKBENCH_PRIVATE_JWK_JSON OIDC_TOKEN_ENDPOINT
  LEGACY_CONNECTORS_DATABASE_URL LEGACY_CONNECTORS_DATABASE_ROLE_PASSWORD
  LEDGER_CORE_METRICS_TOKEN WORKBENCH_METRICS_TOKEN
)
for variable_name in "${required[@]}"; do
  if [ -z "${!variable_name:-}" ]; then
    echo "$variable_name must be configured in $ENV_FILE" >&2
    exit 1
  fi
done

images=(
  "mavula/identity-access:$IMAGE_TAG"
  "mavula/ledger-core:$IMAGE_TAG"
  "mavula/workbench:$IMAGE_TAG"
)

if [ "$REBUILD_IMAGES" = "true" ]; then
  if [ -z "${MINIKUBE_IMAGE_TAG:-}" ] || [ "$IMAGE_TAG" = "minikube" ] || [ "$IMAGE_TAG" = "latest" ]; then
    echo "MINIKUBE_IMAGE_TAG must be an explicit immutable local tag when rebuilding images." >&2
    exit 1
  fi
  docker build -t "${images[0]}" -f "$ROOT_DIR/packages/identity-access/Dockerfile.workspace" "$ROOT_DIR"
  docker build -t "${images[1]}" -f "$ROOT_DIR/packages/ledger-core/Dockerfile" "$ROOT_DIR"
  docker build -t "${images[2]}" -f "$ROOT_DIR/packages/workbench/Dockerfile" "$ROOT_DIR"
else
  for image_name in "${images[@]}"; do
    docker image inspect "$image_name" >/dev/null 2>&1 || {
      echo "Required local image $image_name does not exist." >&2
      echo "Build intentionally with MINIKUBE_REBUILD_IMAGES=true or select an existing MINIKUBE_IMAGE_TAG." >&2
      exit 1
    }
  done
fi

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  echo "Minikube profile $PROFILE must already exist and be running." >&2
  echo "Start it explicitly before deployment; this script does not create clusters." >&2
  exit 1
fi

if [ "$LOAD_IMAGES" = "true" ]; then
  for image_name in "${images[@]}"; do
    minikube image load -p "$PROFILE" "$image_name"
  done
else
  available_images=$(minikube image ls -p "$PROFILE")
  for image_name in "${images[@]}"; do
    if ! grep -Fq "$image_name" <<<"$available_images"; then
      echo "Image $image_name is not present in Minikube profile $PROFILE." >&2
      echo "Load existing images explicitly with MINIKUBE_LOAD_IMAGES=true." >&2
      exit 1
    fi
  done
fi

kubectl --context "$CONTEXT" apply -f "$ROOT_DIR/packages/operations/kubernetes/overlays/minikube/base/namespace.yaml"
secret_dir=$(mktemp -d)
trap 'rm -rf "$secret_dir"' EXIT

{
  printf 'NODE_ENV=development\nPORT=3020\n'
  printf 'DATABASE_URL=%s\n' "$IDENTITY_DATABASE_URL"
  printf 'IDENTITY_ISSUER=%s\n' "$IDENTITY_ISSUER"
  printf 'IDENTITY_JWKS_JSON=%s\n' "$IDENTITY_JWKS_JSON"
  printf 'IDENTITY_COOKIE_KEYS=%s\n' "$IDENTITY_COOKIE_KEYS"
  printf 'IDENTITY_AUDIENCE=%s\n' "${IDENTITY_AUDIENCE:-urn:mavula:identity-access}"
  printf 'IDENTITY_TRUST_PROXY_HOPS=%s\n' "${IDENTITY_TRUST_PROXY_HOPS:-0}"
  printf 'IDENTITY_RESOURCE_AUDIENCES=%s\n' "${IDENTITY_RESOURCE_AUDIENCES:-urn:mavula:identity-access,urn:mavula:ledger-core,urn:mavula:workbench}"
} >"$secret_dir/identity-access.env"
{
  printf 'NODE_ENV=development\nPORT=3000\n'
  printf 'DATABASE_URL=%s\n' "$LEDGER_CORE_DATABASE_URL"
  printf 'REDIS_URL=%s\n' "${REDIS_URL:-redis://redis:6379}"
  printf 'OIDC_ISSUER=%s\n' "$IDENTITY_ISSUER"
  printf 'OIDC_AUTHORIZATION_ENDPOINT=%s\n' "$OIDC_AUTHORIZATION_ENDPOINT"
  printf 'OIDC_AUDIENCE=urn:mavula:ledger-core\n'
  printf 'OIDC_JWKS_URI=%s\n' "$OIDC_JWKS_URI"
  printf 'LEDGER_CORE_IDEMPOTENCY_RETENTION_DAYS=%s\n' "${LEDGER_CORE_IDEMPOTENCY_RETENTION_DAYS:-365}"
  printf 'LEDGER_CORE_IDEMPOTENCY_CLEANUP_INTERVAL_MS=%s\n' "${LEDGER_CORE_IDEMPOTENCY_CLEANUP_INTERVAL_MS:-3600000}"
  printf 'LEDGER_CORE_IDEMPOTENCY_CLEANUP_BATCH_SIZE=%s\n' "${LEDGER_CORE_IDEMPOTENCY_CLEANUP_BATCH_SIZE:-500}"
  printf 'LEDGER_CORE_METRICS_TOKEN=%s\n' "$LEDGER_CORE_METRICS_TOKEN"
} >"$secret_dir/ledger-core.env"
{
  printf 'NODE_ENV=development\nPORT=3010\n'
  printf 'WORKBENCH_DATABASE_URL=%s\n' "$WORKBENCH_DATABASE_URL"
  printf 'SETTLEMENTS_DATABASE_URL=%s\n' "$SETTLEMENTS_DATABASE_URL"
  printf 'LEGACY_CONNECTORS_DATABASE_URL=%s\n' "$LEGACY_CONNECTORS_DATABASE_URL"
  printf 'REDIS_URL=%s\n' "${REDIS_URL:-redis://redis:6379}"
  printf 'OIDC_ISSUER=%s\n' "$IDENTITY_ISSUER"
  printf 'OIDC_AUDIENCE=urn:mavula:workbench\n'
  printf 'OIDC_JWKS_URI=%s\n' "$OIDC_JWKS_URI"
  printf 'OIDC_TOKEN_ENDPOINT=%s\n' "$OIDC_TOKEN_ENDPOINT"
  printf 'WORKBENCH_OIDC_CLIENT_ID=%s\n' "$WORKBENCH_OIDC_CLIENT_ID"
  printf 'WORKBENCH_PRIVATE_JWK_JSON=%s\n' "$WORKBENCH_PRIVATE_JWK_JSON"
  printf 'LEDGER_CORE_AUDIENCE=urn:mavula:ledger-core\n'
  printf 'WORKBENCH_WORKER_ENABLED=true\nWORKBENCH_SCHEDULER_ENABLED=true\n'
  printf 'WORKBENCH_QUEUES=payments,platform,legacy\nWORKBENCH_PAYMENT_PROCESS_STORE=postgres\n'
  printf 'WORKBENCH_LEGACY_BATCH_STORE=postgres\n'
  printf 'WORKBENCH_JOB_RECEIPT_STORE=postgres\n'
  printf 'WORKBENCH_JOB_RECEIPT_RETENTION_DAYS=%s\n' "${WORKBENCH_JOB_RECEIPT_RETENTION_DAYS:-365}"
  printf 'WORKBENCH_METRICS_TOKEN=%s\n' "$WORKBENCH_METRICS_TOKEN"
  printf 'SETTLEMENTS_OUTBOX_ENABLED=false\nSETTLEMENTS_OUTBOX_PUBLISHER_ENABLED=false\n'
} >"$secret_dir/workbench.env"
chmod 600 "$secret_dir"/*.env

for service_name in identity-access ledger-core workbench; do
  kubectl --context "$CONTEXT" create secret generic "$service_name-secrets" \
    --namespace "$NAMESPACE" --from-env-file="$secret_dir/$service_name.env" \
    --dry-run=client -o yaml | kubectl --context "$CONTEXT" apply -f -
done

kubectl kustomize --load-restrictor=LoadRestrictionsNone \
  "$ROOT_DIR/packages/operations/kubernetes/overlays/minikube" | kubectl --context "$CONTEXT" apply -f -
kubectl --context "$CONTEXT" set image deployment/identity-access "identity-access=${images[0]}" -n "$NAMESPACE"
kubectl --context "$CONTEXT" set image deployment/ledger-core "ledger-core=${images[1]}" -n "$NAMESPACE"
kubectl --context "$CONTEXT" set image deployment/workbench "workbench=${images[2]}" -n "$NAMESPACE"
kubectl --context "$CONTEXT" rollout status statefulset/postgres -n "$NAMESPACE" --timeout=180s
kubectl --context "$CONTEXT" rollout status statefulset/redis -n "$NAMESPACE" --timeout=180s

kubectl --context "$CONTEXT" port-forward service/postgres "$DATABASE_PORT:5432" -n "$NAMESPACE" >/tmp/mavula-postgres-forward.log 2>&1 &
FORWARD_PID=$!
trap 'kill "$FORWARD_PID" >/dev/null 2>&1 || true; rm -rf "$secret_dir"' EXIT
for _ in $(seq 1 30); do
  if (echo >/dev/tcp/127.0.0.1/"$DATABASE_PORT") >/dev/null 2>&1; then break; fi
  sleep 1
done
LOCAL_MIGRATION_DATABASE_URL="postgresql://mavula:mavula_dev@127.0.0.1:$DATABASE_PORT/mavula"
DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=identity" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/identity-access --fail-if-no-match prisma:migrate
DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=workbench" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/workbench --fail-if-no-match prisma:migrate
WORKBENCH_MIGRATION_DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=workbench" \
WORKBENCH_DATABASE_ROLE_PASSWORD="$WORKBENCH_DATABASE_ROLE_PASSWORD" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/workbench --fail-if-no-match database:provision-role
DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=settlements" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/settlements --fail-if-no-match prisma:migrate
DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=legacy_connectors" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/legacy-connectors --fail-if-no-match prisma:migrate
LEGACY_CONNECTORS_MIGRATION_DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=legacy_connectors" \
LEGACY_CONNECTORS_DATABASE_ROLE_PASSWORD="$LEGACY_CONNECTORS_DATABASE_ROLE_PASSWORD" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/legacy-connectors --fail-if-no-match database:provision-role
LEDGER_CORE_MIGRATION_DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=public" \
LEDGER_CORE_DATABASE_ROLE_PASSWORD="$LEDGER_CORE_DATABASE_ROLE_PASSWORD" \
LEDGER_CORE_ACCEPT_BASELINE="${LEDGER_CORE_ACCEPT_BASELINE:-false}" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/ledger-core database:migrate
LEDGER_CORE_MIGRATION_DATABASE_URL="$LOCAL_MIGRATION_DATABASE_URL?schema=public" \
LEDGER_CORE_DATABASE_ROLE_PASSWORD="$LEDGER_CORE_DATABASE_ROLE_PASSWORD" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/ledger-core database:provision-role
kill "$FORWARD_PID" >/dev/null 2>&1 || true
trap 'rm -rf "$secret_dir"' EXIT

for deployment_name in identity-access ledger-core workbench; do
  kubectl --context "$CONTEXT" rollout status "deployment/$deployment_name" -n "$NAMESPACE" --timeout=180s
done

kubectl --context "$CONTEXT" get pods,services,pvc -n "$NAMESPACE"
echo "Deployed existing local image tag: $IMAGE_TAG"
