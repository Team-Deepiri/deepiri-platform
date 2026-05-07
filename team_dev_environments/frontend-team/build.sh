#!/bin/bash
# Frontend Team - Build script
# Builds frontend team services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder. Docker Desktop / WSL2 on Windows hosts hits a
# BuildKit snapshot-commit bug ("snapshot does not exist: not found")
# that also masks real errors as generic "runc process is already dead".
# The legacy builder is slower but reliable.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

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
