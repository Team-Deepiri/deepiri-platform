#!/usr/bin/env bash
# Compatibility wrapper — logic lives in teams/*.yml + setup-deepiri-dev.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEAM="$(basename "$(cd "$(dirname "$0")" && pwd)")"
CMD="stop-rm"
exec bash "$REPO_ROOT/setup-deepiri-dev.sh" "$CMD" "$TEAM"

