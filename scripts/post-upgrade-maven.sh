#!/bin/bash
# DEPRECATED: use scripts/post-upgrade.sh instead.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$SCRIPT_DIR/post-upgrade.sh" "$@"
