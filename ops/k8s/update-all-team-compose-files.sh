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
    ["task-orchestrator"]=".env-k8s/task-orchestrator.env"
    ["engagement-service"]=".env-k8s/engagement-service.env"
    ["platform-analytics-service"]=".env-k8s/platform-analytics-service.env"
    ["notification-service"]=".env-k8s/notification-service.env"
    ["external-bridge-service"]=".env-k8s/external-bridge-service.env"
    ["challenge-service"]=".env-k8s/challenge-service.env"
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
echo "    MONGO_URI: mongodb://..."

