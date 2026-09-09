#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPLOY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ENV_FILE=${ENV_FILE:-"$DEPLOY_ROOT/.env"}

"$SCRIPT_DIR/backup.sh"
docker compose --env-file "$ENV_FILE" -f "$DEPLOY_ROOT/compose.yaml" --profile external-ragflow config >/dev/null
docker compose --env-file "$ENV_FILE" -f "$DEPLOY_ROOT/compose.yaml" --profile external-ragflow build --pull=false
docker compose --env-file "$ENV_FILE" -f "$DEPLOY_ROOT/compose.yaml" --profile external-ragflow up -d --remove-orphans
"$SCRIPT_DIR/smoke.sh"
