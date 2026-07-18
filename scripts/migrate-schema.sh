#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT_DIR"

ENV_FILE=${MAVULA_ENV_FILE:-"$ROOT_DIR/.env"}
if [ ! -f "$ENV_FILE" ]; then
  echo "Local configuration is required at $ENV_FILE" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

PNPM_BIN=${PNPM_BIN:-"$HOME/.local/share/pnpm/pnpm"}

DATABASE_URL=${WORKBENCH_MIGRATION_DATABASE_URL:?WORKBENCH_MIGRATION_DATABASE_URL is required} \
  PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/workbench prisma:migrate
PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/workbench database:provision-role
DATABASE_URL=${SETTLEMENTS_MIGRATION_DATABASE_URL:?SETTLEMENTS_MIGRATION_DATABASE_URL is required} \
  PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/settlements prisma:migrate
DATABASE_URL=${LEGACY_CONNECTORS_MIGRATION_DATABASE_URL:?LEGACY_CONNECTORS_MIGRATION_DATABASE_URL is required} \
  PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/legacy-connectors prisma:migrate
PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/legacy-connectors database:provision-role
DATABASE_URL=${IDENTITY_DATABASE_URL:?IDENTITY_DATABASE_URL is required} \
  PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/identity-access prisma:migrate
PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/ledger-core database:migrate
PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/ledger-core database:provision-role
