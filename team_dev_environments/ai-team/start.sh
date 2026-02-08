#!/bin/bash
# AI Team - Start script
# Starts AI/ML services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# ------------------------------------------------------------
# Device backend detection (CUDA vs MPS vs Other)
# ------------------------------------------------------------
BACKEND="other"

if command -v nvidia-smi >/dev/null 2>&1; then
  BACKEND="cuda"
elif [[ "$(uname)" == "Darwin" ]]; then
  BACKEND="mps"
fi

echo "🧠 Detected backend: ${BACKEND}"
echo ""

# ------------------------------------------------------------
# AI team services
# ------------------------------------------------------------
SERVICES=(
  postgres redis influxdb etcd minio milvus
  cyrex cyrex-interface mlflow
  # jupyter  # DISABLED: No services depend on Jupyter - it's only for manual research/experimentation
  challenge-service api-gateway messaging-service realtime-gateway
  ollama synapse
)

# ------------------------------------------------------------
# MPS-specific filtering
# ------------------------------------------------------------
if [[ "${BACKEND}" == "mps" ]]; then
  echo "⚠️  MPS detected — excluding cyrex and ollama from Docker startup"
  SERVICES=($(printf "%s\n" "${SERVICES[@]}" | grep -v -E '^(cyrex|ollama)$'))
  echo ""
fi

echo "🚀 Starting AI Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Use --no-build to prevent automatic building (images should already be built)
# --no-deps prevents starting dependencies unless specified (API gateway doesn't need auth-service or language-intelligence-service to start)
docker compose -f docker-compose.dev.yml up -d --no-build --no-deps "${SERVICES[@]}"

echo ""
echo "✅ AI Team docker services started!"

echo ""
if [[ "${BACKEND}" != "mps" ]]; then
  echo "🤖 Cyrex: http://localhost:8000"
fi

echo "🎨 Cyrex Interface: http://localhost:5175"

if [[ "${BACKEND}" != "mps" ]]; then
  echo "🤖 Ollama: http://localhost:11434"
fi

echo "📡 Synapse: http://localhost:8002"

API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🏆 Challenge Service: http://localhost:5007"
echo ""

if [[ "${BACKEND}" != "mps" ]]; then
  echo "💡 To pull models into Ollama: docker exec -it deepiri-ollama-ai ollama pull llama3:8b"
else
  echo "1. On a separate terminal, run:"
  echo "   ollama serve"
  echo "2. To pull models into Ollama, open a separate terminal and run:"
  echo "   ollama pull llama3:8b"
  echo "3. to start Cyrex service natively using MPS, open a separate terminal and run:"
  echo "   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
fi