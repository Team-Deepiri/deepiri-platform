#!/usr/bin/env bash
ACTION=${1:-}
TEAM=${2:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ "$ACTION" != "pull" ] || [ -z "$TEAM" ]; then
  echo "Usage: ./submodules.sh pull [backend|frontend|ai|infrastructure|qa|ml|platform|all|qa-tier-1|qa-tier-2|qa-tier-3]"
  exit 1
fi
exec bash "$REPO_ROOT/setup-deepiri-dev.sh" pull "$TEAM"
