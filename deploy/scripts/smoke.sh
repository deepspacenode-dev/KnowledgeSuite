#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPLOY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ENV_FILE=${ENV_FILE:-"$DEPLOY_ROOT/.env"}

set -a
. "$ENV_FILE"
set +a

BASE_URL=${BOOKSTACK_APP_URL:-http://127.0.0.1:6875}
curl -fsS "$BASE_URL/login" >/dev/null
status=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/api/ai-governance/v2/intakes/1")
case "$status" in
  401|403|404|200) ;;
  *) printf '%s\n' "Unexpected governance route status: $status" >&2; exit 3 ;;
esac

if [ -n "${RAGFLOW_BASE_URL:-}" ]; then
  curl -fsS -H "Authorization: Bearer ${RAGFLOW_API_KEY:-}" \
    "${RAGFLOW_BASE_URL%/}${RAGFLOW_VERSION_PATH:-/api/v1/system/version}" >/dev/null
fi

printf '%s\n' "Smoke test passed: $BASE_URL"
