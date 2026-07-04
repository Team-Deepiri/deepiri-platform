#!/usr/bin/env bash
# Build platform backend Docker images (compose.dev services + shared-utils prep).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

PLATFORM_SERVICES=(
  api-gateway
  auth-service
  workflow-orchestrator
  incentive-engine
  decision-intelligence
  external-bridge-service
  adaptive-experience-engine
  language-intelligence-service
  communications-hub
  messaging-service
  realtime-gateway
  synapse
  synapse-sugar-glider
)

ensure_suite_image() {
  local tag="$1"
  local base="$2"
  local img="ghcr.io/team-deepiri/deepiri-suite:${tag}"
  if docker image inspect "$img" >/dev/null 2>&1; then
    echo "  ok $img (cached)"
    return 0
  fi
  echo "  pulling $img..."
  if docker pull "$img" 2>/dev/null; then
    echo "  ok $img (pulled)"
    return 0
  fi
  echo "  building $img from deepiri-suite submodule..."
  docker build --build-arg "BASE_IMAGE=${base}" -t "$img" ./deepiri-suite
}

echo "==> Ensuring deepiri-suite base images"
ensure_suite_image "18-alpine" "node:18-alpine"
ensure_suite_image "18-slim" "node:18-slim"
ensure_suite_image "20-alpine" "node:20-alpine"

echo "==> Building deepiri-shared-utils (required by Node service Dockerfiles)"
npm ci --legacy-peer-deps --prefix platform-services/shared/deepiri-shared-utils
npm run build --prefix platform-services/shared/deepiri-shared-utils

echo "==> Building platform services via docker-compose.dev.yml"
failed=()
for svc in "${PLATFORM_SERVICES[@]}"; do
  echo ""
  echo "── docker compose build $svc ──"
  if ! docker compose -f docker-compose.dev.yml build "$svc"; then
    failed+=("$svc")
  fi
done

if ((${#failed[@]} > 0)); then
  echo ""
  echo "FAILED builds: ${failed[*]}"
  exit 1
fi

echo ""
echo "All platform service images built successfully."
