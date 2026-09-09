#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPLOY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ENV_FILE=${ENV_FILE:-"$DEPLOY_ROOT/.env"}

: "${ROLLBACK_BOOKSTACK_IMAGE:?set ROLLBACK_BOOKSTACK_IMAGE to the previously verified image tag or digest}"
: "${ROLLBACK_WORKER_IMAGE:?set ROLLBACK_WORKER_IMAGE to the previously verified image tag or digest}"

DRV_BOOKSTACK_IMAGE=$ROLLBACK_BOOKSTACK_IMAGE \
DRV_WORKER_IMAGE=$ROLLBACK_WORKER_IMAGE \
docker compose --env-file "$ENV_FILE" -f "$DEPLOY_ROOT/compose.yaml" --profile external-ragflow up -d --no-build

printf '%s\n' 'Application images rolled back. Governance tables and BookStack/MariaDB data were preserved.'
