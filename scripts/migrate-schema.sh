#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT_DIR"

PNPM_BIN=${PNPM_BIN:-"$HOME/.local/share/pnpm/pnpm"}

PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/settlements prisma:migrate
PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/identity-access prisma:migrate
PATH="$HOME/.local/share/pnpm:$PATH" "$PNPM_BIN" --filter @mavula/ledger-core prisma:migrate
