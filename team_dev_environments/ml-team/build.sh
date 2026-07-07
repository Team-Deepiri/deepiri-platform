#!/bin/bash
# ML Team - Build script
# Builds ML team services using docker-compose.dev.yml with service selection

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

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

# ML team services
SERVICES=(
  postgres redis influxdb
  mlflow
  # jupyter  # DISABLED: No services depend on Jupyter - it's only for manual research/experimentation
  platform-analytics-service synapse sugar-glider
)

echo "🔨 Building ML Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"
