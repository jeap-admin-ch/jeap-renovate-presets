#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
FIXTURE_DIR="$ROOT_DIR/tests/fixtures/compatibility-aware-kafka-message-deps"
PRESET="$ROOT_DIR/presets/compatibility-aware-kafka-message-deps.json"
SERVER_LOG=$(mktemp)
RENOVATE_LOG=$(mktemp)
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$SERVER_LOG" "$RENOVATE_LOG"
}
trap cleanup EXIT

python3 "$ROOT_DIR/tests/renovate-datasource-server.py" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
sleep 1

docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  -v "$FIXTURE_DIR:/repo:ro" \
  -v "$PRESET:/preset.json:ro" \
  -w /repo \
  -e RENOVATE_CONFIG_FILE=/preset.json \
  -e RENOVATE_REQUIRE_CONFIG=ignored \
  -e LOG_LEVEL=debug \
  renovate/renovate:43.265.4 \
  --platform=local --dry-run=lookup >"$RENOVATE_LOG" 2>&1

if ! grep -q 'jme-create-declaration-command' "$SERVER_LOG"; then
  cat "$SERVER_LOG"
  cat "$RENOVATE_LOG"
  echo "Custom datasource was not called for the Maven dependency" >&2
  exit 1
fi

if ! grep -Eq 'currentValue=1\.0\.0.*appName=configure-me.*environment=PROD' "$SERVER_LOG"; then
  cat "$SERVER_LOG"
  echo "Renovate did not send the configured datasource context" >&2
  exit 1
fi

if ! grep -q '1.1.0' "$RENOVATE_LOG"; then
  cat "$RENOVATE_LOG"
  echo "Compatible release was not selected by Renovate" >&2
  exit 1
fi

echo "Compatibility-aware Renovate datasource POC passed"
