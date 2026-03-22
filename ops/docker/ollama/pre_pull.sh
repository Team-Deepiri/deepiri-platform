#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Starting Ollama for pre-pull"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ollama serve &
OLLAMA_PID=$!

echo "⏳ Waiting for Ollama..."

for i in $(seq 1 60); do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama ready"
        break
    fi
    sleep 1
done

echo "📦 Models to pull: $MODELS"

for model in $MODELS; do
    echo "➡️ Pulling $model"
    if ollama pull "$model"; then
        echo "✅ Success: $model"
    else
        echo "⚠️ Failed: $model"
    fi
done

echo "🛑 Stopping Ollama..."
kill $OLLAMA_PID 2>/dev/null || true
wait $OLLAMA_PID 2>/dev/null || true

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Pre-pull completed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"