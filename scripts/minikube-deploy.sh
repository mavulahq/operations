#!/usr/bin/env bash
# mavula.io - Local Minikube deployment
# Copyright (c) 2026 mavula.io
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../.." && pwd)
PROFILE=${MINIKUBE_PROFILE:-getfluxo}
DRIVER=${MINIKUBE_DRIVER:-docker}
CONTEXT=$PROFILE
NAMESPACE=mavula
IMAGE_TAG=${MINIKUBE_IMAGE_TAG:-minikube-$(date -u +%Y%m%d%H%M%S)}
DATABASE_PORT=${MINIKUBE_DATABASE_PORT:-15433}

command -v minikube >/dev/null || { echo "minikube is required" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v pnpm >/dev/null || { echo "pnpm is required" >&2; exit 1; }

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" --driver="$DRIVER"
fi

docker build -t "mavula/ledger-core:$IMAGE_TAG" -f "$ROOT_DIR/packages/ledger-core/Dockerfile" "$ROOT_DIR"
docker build -t "mavula/workbench:$IMAGE_TAG" -f "$ROOT_DIR/packages/workbench/Dockerfile" "$ROOT_DIR"
minikube image load -p "$PROFILE" "mavula/ledger-core:$IMAGE_TAG"
minikube image load -p "$PROFILE" "mavula/workbench:$IMAGE_TAG"

kubectl kustomize --load-restrictor=LoadRestrictionsNone \
  "$ROOT_DIR/packages/operations/kubernetes/overlays/minikube" | kubectl --context "$CONTEXT" apply -f -
kubectl --context "$CONTEXT" set image deployment/ledger-core "ledger-core=mavula/ledger-core:$IMAGE_TAG" -n "$NAMESPACE"
kubectl --context "$CONTEXT" set image deployment/workbench "workbench=mavula/workbench:$IMAGE_TAG" -n "$NAMESPACE"
kubectl --context "$CONTEXT" rollout status statefulset/postgres -n "$NAMESPACE" --timeout=180s
kubectl --context "$CONTEXT" rollout status statefulset/redis -n "$NAMESPACE" --timeout=180s

kubectl --context "$CONTEXT" port-forward service/postgres "$DATABASE_PORT:5432" -n "$NAMESPACE" >/tmp/mavula-postgres-forward.log 2>&1 &
FORWARD_PID=$!
trap 'kill "$FORWARD_PID" >/dev/null 2>&1 || true' EXIT
for _ in $(seq 1 30); do
  if (echo >/dev/tcp/127.0.0.1/"$DATABASE_PORT") >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
LEDGER_CORE_DATABASE_URL="postgresql://mavula:mavula_dev@127.0.0.1:$DATABASE_PORT/mavula?schema=public"
SETTLEMENTS_DATABASE_URL="postgresql://mavula:mavula_dev@127.0.0.1:$DATABASE_PORT/mavula?schema=settlements"
DATABASE_URL="$SETTLEMENTS_DATABASE_URL" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/settlements --fail-if-no-match prisma:migrate
DATABASE_URL="$LEDGER_CORE_DATABASE_URL" \
  pnpm --dir "$ROOT_DIR" --filter @mavula/ledger-core exec prisma db push --skip-generate
kill "$FORWARD_PID" >/dev/null 2>&1 || true
trap - EXIT

kubectl --context "$CONTEXT" rollout status deployment/ledger-core -n "$NAMESPACE" --timeout=180s
kubectl --context "$CONTEXT" rollout status deployment/workbench -n "$NAMESPACE" --timeout=180s

kubectl --context "$CONTEXT" get pods,services,pvc -n "$NAMESPACE"
echo "Deployed local image tag: $IMAGE_TAG"
echo "Run 'minikube service workbench -n $NAMESPACE -p $PROFILE --url' to access the public status API."
