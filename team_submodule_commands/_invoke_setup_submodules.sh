#!/usr/bin/env bash
# Delegate to setup-deepiri-dev.sh (canonical submodule init for every team).
set -euo pipefail

TEAM_KEY="${1:?team key required (ai, backend, frontend, infrastructure, ml, platform, qa, cyrex)}"
MODE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

args=(--team "$TEAM_KEY" --submodules-only --skip-docker --non-interactive)
if [[ "$MODE" == "--update" ]]; then
    args+=(--update-submodules)
fi

exec bash "$REPO_ROOT/setup-deepiri-dev.sh" "${args[@]}"
