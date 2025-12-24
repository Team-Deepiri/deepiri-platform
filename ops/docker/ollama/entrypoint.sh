#!/bin/bash
set -e

# Start Ollama in the background
echo "🚀 Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down Ollama..."
    kill $OLLAMA_PID 2>/dev/null || true
    wait $OLLAMA_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Wait for Ollama to be ready
echo "⏳ Waiting for Ollama to be ready..."
MAX_WAIT=60
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check if ollama is responding by trying to list models
    if ollama list > /dev/null 2>&1; then
        echo "✅ Ollama is ready!"
        break
    fi
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
    echo "   Still waiting... (${WAIT_TIME}s/${MAX_WAIT}s)"
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo "❌ Ollama failed to start within ${MAX_WAIT} seconds"
    kill $OLLAMA_PID 2>/dev/null || true
    exit 1
fi

# Check if llama3:8b is already installed
echo "🔍 Checking if llama3:8b is installed..."
if ollama list 2>/dev/null | grep -q "llama3:8b"; then
    echo "✅ llama3:8b is already installed"
else
    echo "📦 Installing llama3:8b..."
    ollama pull llama3:8b
    echo "✅ llama3:8b installed successfully!"
fi

# Keep the container running
echo "🎉 Ollama is ready with llama3:8b!"
wait $OLLAMA_PID

