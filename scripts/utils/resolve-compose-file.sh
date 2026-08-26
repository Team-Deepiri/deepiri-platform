#!/usr/bin/env bash
# Resolve COMPOSE_FILE for cloud portal vs control-plane layouts.
# Source from repo root: . scripts/utils/resolve-compose-file.sh && resolve_compose_file

resolve_compose_file() {
  local root="${1:-.}"
  COMPOSE_FILE=""
  REPO_ROLE=""

  if [[ -f "$root/docker-compose.yml" ]] \
     && grep -q 'postgres-platform' "$root/docker-compose.yml" 2>/dev/null; then
    COMPOSE_FILE="$root/docker-compose.yml"
    REPO_ROLE="cloud-portal"
    return 0
  fi

  if [[ -f "$root/docker-compose.dev.yml" ]] \
     && grep -q '^  cyrex:' "$root/docker-compose.dev.yml" 2>/dev/null; then
    COMPOSE_FILE="$root/docker-compose.dev.yml"
    REPO_ROLE="control-plane"
    return 0
  fi

  echo "Cannot detect compose file." >&2
  echo "  Cloud VPS portal → clone Team-Deepiri/deepiri-platform" >&2
  echo "  Full dev stack     → clone Team-Deepiri/deepiri-control-plane" >&2
  return 1
}
