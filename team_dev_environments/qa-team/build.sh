#!/bin/bash
# QA Team - Build script
# Builds: All backend microservices using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder. Docker Desktop / WSL2 on this machine hits a
# BuildKit snapshot-commit bug ("snapshot does not exist: not found")
# that also masks real errors as generic "runc process is already dead".
# The legacy builder is slower but reliable.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb kafka
  api-gateway auth-service workflow-orchestrator
  incentive-engine decision-intelligence
  communications-hub external-bridge-service
  adaptive-experience-engine realtime-gateway
  language-intelligence-service messaging-service
  synapse synapse-sugar-glider frontend-dev adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🔨 Building QA Team services: ${SERVICES[*]}"

docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"
