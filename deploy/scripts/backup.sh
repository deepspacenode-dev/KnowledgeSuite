#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPLOY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=${BACKUP_ROOT:-"$DEPLOY_ROOT/backups/$(date +%Y%m%d-%H%M%S)"}
ENV_FILE=${ENV_FILE:-"$DEPLOY_ROOT/.env"}

[ -f "$ENV_FILE" ] || { printf '%s\n' "Missing environment file: $ENV_FILE" >&2; exit 2; }
mkdir -p "$BACKUP_ROOT"

docker compose --env-file "$ENV_FILE" -f "$DEPLOY_ROOT/compose.yaml" --profile external-ragflow exec -T governance-db \
  sh -lc 'exec mariadb-dump --single-transaction --routines --events -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' \
  > "$BACKUP_ROOT/bookstack.sql"

docker compose --env-file "$ENV_FILE" -f "$DEPLOY_ROOT/compose.yaml" --profile external-ragflow exec -T governance-bookstack \
  tar czf - -C /config . > "$BACKUP_ROOT/bookstack-config.tar.gz"

sha256sum "$BACKUP_ROOT/bookstack.sql" "$BACKUP_ROOT/bookstack-config.tar.gz" > "$BACKUP_ROOT/SHA256SUMS"
printf '%s\n' "Backup created: $BACKUP_ROOT"
