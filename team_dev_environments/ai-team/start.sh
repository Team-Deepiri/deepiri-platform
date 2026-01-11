#!/bin/bash
# AI Team - Start script
# Starts AI/ML services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# AI team services
SERVICES=(
  redis influxdb etcd minio milvus
  cyrex cyrex-interface jupyter mlflow
  challenge-service api-gateway
  ollama synapse
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
echo "📡 Synapse: http://localhost:8002"
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🏆 Challenge Service: http://localhost:5007"
echo ""
echo "💡 To pull models into Ollama: docker exec -it deepiri-ollama-ai ollama pull llama3:8b"
