#!/bin/bash
# Frontend Team - Build script
# Builds frontend team services using docker-compose.dev.yml with service selection

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Force legacy builder. Docker Desktop / WSL2 on Windows hosts hits a
# BuildKit snapshot-commit bug ("snapshot does not exist: not found")
# that also masks real errors as generic "runc process is already dead".
# The legacy builder is slower but reliable.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

ensure_suite_images() {
  local repo_root="$1"
  local suite_dir="${DEEPIRI_SUITE_CONTEXT:-${repo_root}/deepiri-suite}"
  echo "Ensuring deepiri-suite base images..."
  local all_ok=true
  for spec in "node:18-alpine:18-alpine" "node:18-slim:18-slim" "node:20-alpine:20-alpine"; do
    local base="${spec%%:*}"
    local tag="${spec##*:}"
    local img="ghcr.io/team-deepiri/deepiri-suite:${tag}"
    if docker image inspect "$img" >/dev/null 2>&1; then
      echo "   ok $img (cached)"
      continue
    fi
    echo "   Pulling $img from GHCR..."
    if docker pull "$img" 2>/dev/null; then
      echo "   ok $img (pulled)"
      continue
    fi
    echo "   GHCR pull failed -- building locally (BASE_IMAGE=$base)"
    if [ ! -f "${suite_dir}/Dockerfile" ]; then
      echo "   deepiri-suite submodule not found at ${suite_dir}"
      echo "      Run: git submodule update --init deepiri-suite"
      all_ok=false
      continue
    fi
    if docker build --build-arg "BASE_IMAGE=${base}" -t "$img" "$suite_dir"; then
      echo "   ok $img (built locally)"
    else
      echo "   Failed to build $img locally"
      all_ok=false
    fi
  done
  [ "$all_ok" = false ] && return 1 || return 0
}

ensure_suite_images "$REPO_ROOT" || exit 1

# Frontend team services - only what frontend engineers need
SERVICES=(
  frontend-dev
  api-gateway
  auth-service
  communications-hub
  messaging-service
  realtime-gateway
  postgres-auth
  postgres-core
  postgres-intelligence
)

echo "🔨 Building Frontend Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services sequentially. Windows Docker Desktop / WSL2 runs out of
# runc/BuildKit resources when 10+ npm installs run in parallel, causing
# "runc run failed: container process is already dead" and snapshot errors.
# Sequential builds are slower but reliable.
failed=()
for svc in "${SERVICES[@]}"; do
  echo ""
  echo "── Building $svc ──"
  if ! docker compose -f docker-compose.dev.yml build "$svc"; then
    echo "❌ $svc failed"
    failed+=("$svc")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo ""
  echo "❌ Failed services: ${failed[*]}"
  exit 1
fi

echo ""
echo "✅ Frontend Team services built successfully!"
echo "   Built services: ${SERVICES[*]}"
