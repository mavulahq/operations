#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-mavula/ledger-core}
IMAGE_TAG=${IMAGE_TAG:-latest}

docker push "${IMAGE_NAME}:${IMAGE_TAG}"
