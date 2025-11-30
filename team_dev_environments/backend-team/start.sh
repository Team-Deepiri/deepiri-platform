#!/bin/bash
# Backend Team - Start Script
# Starts all backend services with k8s configmaps and secrets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🚀 Starting Backend Team Environment..."
echo "   (Using k8s configmaps and secrets from ops/k8s/)"
echo ""

# Use wrapper to auto-load k8s config
./docker-compose-k8s.sh -f docker-compose.backend-team.yml up -d

echo ""
echo "✅ Backend Team Environment Started!"
echo ""
echo "Access your services:"
echo "  - Frontend:        http://localhost:5173"
echo "  - API Gateway:     http://localhost:5100"
echo "  - Auth Service:    http://localhost:5001"
echo "  - pgAdmin: http://localhost:5050"
echo "  - Adminer: http://localhost:8080"
echo ""
echo "View logs:"
echo "  docker compose -f docker-compose.backend-team.yml logs -f"
echo ""
