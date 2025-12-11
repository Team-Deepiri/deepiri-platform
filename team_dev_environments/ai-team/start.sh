#!/bin/bash
# AI Team - Start script
# Starts AI/ML services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# AI team services
SERVICES=(
  redis influxdb etcd minio milvus
  cyrex cyrex-interface jupyter mlflow
  challenge-service external-bridge-service
  ollama
)

echo "🚀 Starting AI Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Use --no-build to prevent automatic building (images should already be built)
# --no-deps prevents starting dependencies unless specified
docker compose -f docker-compose.dev.yml up -d --no-build "${SERVICES[@]}"

echo "✅ AI Team services started!"
echo ""
echo "🤖 Cyrex: http://localhost:8000"
echo "🎨 Cyrex Interface: http://localhost:5175"
echo "🤖 Ollama: http://localhost:11434"
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🎮 Engagement Service: http://localhost:5003"
echo "🏆 Challenge Service: http://localhost:5007"
echo "🌉 External Bridge: http://localhost:5006"
echo ""
echo "💡 To pull models into Ollama: docker exec -it deepiri-ollama-ai ollama pull llama3:8b"
