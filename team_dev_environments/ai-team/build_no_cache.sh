#!/usr/bin/env bash
# Compatibility wrapper — no-cache builds use the same YAML path as build for now.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEAM="$(basename "$(cd "$(dirname "$0")" && pwd)")"
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-0}"
exec bash "$REPO_ROOT/setup-deepiri-dev.sh" build "$TEAM"
