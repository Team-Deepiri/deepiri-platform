#!/bin/bash
# Build script for cyrex service with automatic GPU detection and CPU fallback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CYREX_DIR="$PROJECT_ROOT/diri-cyrex"

echo "🔍 Detecting GPU capabilities..."

# Detect GPU and get base image
if [ -f "$CYREX_DIR/detect_gpu.sh" ]; then
    BASE_IMAGE=$(bash "$CYREX_DIR/detect_gpu.sh")
else
    # Fallback: check if nvidia-smi exists
    if command -v nvidia-smi &> /dev/null; then
        echo "NVIDIA GPU detected, using CUDA image" >&2
        BASE_IMAGE="pytorch/pytorch:2.0.0-cuda12.1-cudnn8-runtime"
    else
        echo "No NVIDIA GPU detected, using CPU image" >&2
        BASE_IMAGE="pytorch/pytorch:2.0.0-cpu"
    fi
fi

echo "📦 Using base image: $BASE_IMAGE"
echo "🔨 Building cyrex service..."

# Export BASE_IMAGE for docker-compose
export BASE_IMAGE

# Build with detected base image
cd "$PROJECT_ROOT"
docker compose -f docker-compose.dev.yml build --build-arg BASE_IMAGE="$BASE_IMAGE" cyrex jupyter

echo "✅ Build complete!"

