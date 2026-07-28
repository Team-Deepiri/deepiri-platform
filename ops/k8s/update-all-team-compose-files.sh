#!/bin/bash
# Script to update all team docker-compose files with env_file from k8s configmaps/secrets
# This script applies the same pattern to all team-specific compose files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Updating all team docker-compose files to use env_file from k8s configmaps/secrets..."

# Service to env_file mapping
declare -A SERVICE_ENV_MAP=(
    ["api-gateway"]=".env-k8s/api-gateway.env"
    ["auth-service"]=".env-k8s/auth-service.env"
    ["truss"]=".env-k8s/truss.env"
    ["registry"]=".env-k8s/registry.env"
    ["telemetry"]=".env-k8s/telemetry.env"
    ["external-bridge-service"]=".env-k8s/external-bridge-service.env"
    ["jobs"]=".env-k8s/jobs.env"
    ["realtime-gateway"]=".env-k8s/realtime-gateway.env"
    ["cyrex"]=".env-k8s/cyrex.env"
    ["frontend-dev"]=".env-k8s/frontend-dev.env"
    ["frontend-platform"]=".env-k8s/frontend-dev.env"
    ["frontend-qa"]=".env-k8s/frontend-dev.env"
)

# Files to update
COMPOSE_FILES=(
    "$PROJECT_ROOT/docker-compose.infrastructure-team.yml"
    "$PROJECT_ROOT/docker-compose.platform-engineers.yml"
    "$PROJECT_ROOT/docker-compose.qa-team.yml"
    "$PROJECT_ROOT/docker-compose.ml-team.yml"
    "$PROJECT_ROOT/docker-compose.microservices.yml"
)

echo "Note: This script is a helper. Manual updates are recommended for accuracy."
echo "The pattern to apply is:"
echo "  env_file:"
echo "    - .env-k8s/[service-name].env"
echo "  environment:"
echo "    # Override or add docker-specific variables here if needed"
echo "    PORT: [port-number]"
echo "    REDIS_URL: redis://..."
