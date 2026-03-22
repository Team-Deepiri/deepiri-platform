#!/bin/bash
# Ollama entrypoint script
# Models should be pre-pulled during build, but this handles runtime pulls if needed

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting Ollama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if models exist (from build-time pre-pull)
if [ -d "/root/.ollama/models" ] && [ "$(ls -A /root/.ollama/models 2>/dev/null)" ]; then
    echo "✅ Models found from build-time pre-pull"
else
    echo "ℹ️  No models found from build - will pull at runtime if needed"
fi

# Start Ollama server
echo "🚀 Starting Ollama server..."
exec ollama serve

