#!/bin/bash
# Backend Team - Build script
# Builds: All backend microservices using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder. Docker Desktop / WSL2 on Windows hosts hits a
# BuildKit snapshot-commit bug ("snapshot does not exist: not found")
# that also masks real errors as generic "runc process is already dead".
# The legacy builder is slower but reliable.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

# Backend team services
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  language-intelligence-service messaging-service
  synapse frontend-dev adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🔨 Building Backend Team services..."
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
echo "✅ Backend Team services built successfully!"
echo ""
echo "Services built:"
for service in "${SERVICES[@]}"; do
  echo "  ✓ $service"
done
