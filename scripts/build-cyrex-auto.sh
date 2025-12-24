#!/bin/bash
# Auto-build script that detects GPU and builds accordingly
# Usage: ./build-cyrex-auto.sh [cyrex|jupyter|all]

set -e

SERVICE="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CYREX_DIR="$PROJECT_ROOT/diri-cyrex"

# Detect WSL and use .exe versions if needed
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null || [[ -n "$WSL_DISTRO_NAME" ]]; then
    DOCKER_CMD="docker.exe"
    echo "🔍 WSL detected - using docker.exe"
else
    DOCKER_CMD="docker"
fi

# Test if docker command works
if ! command -v $DOCKER_CMD &> /dev/null; then
    echo "❌ Error: $DOCKER_CMD not found. Please install Docker." >&2
    exit 1
fi

# Test if docker daemon is accessible
if ! $DOCKER_CMD ps &> /dev/null; then
    echo "❌ Error: Cannot connect to Docker daemon. Is Docker running?" >&2
    exit 1
fi

echo "🔍 Auto-detecting GPU capabilities..."

# Detect GPU and get base image
if [ -f "$CYREX_DIR/detect_gpu.sh" ]; then
    BASE_IMAGE=$(bash "$CYREX_DIR/detect_gpu.sh")
else
    # Fallback detection
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
        GPU_MEMORY_GB=$((GPU_MEMORY / 1024))
        if [ "$GPU_MEMORY_GB" -ge 4 ]; then
            echo "GPU detected (${GPU_MEMORY_GB}GB), using CUDA image" >&2
            BASE_IMAGE="pytorch/pytorch:2.0.0-cuda12.1-cudnn8-runtime"
        else
            echo "GPU memory (${GPU_MEMORY_GB}GB) below minimum, using CPU image" >&2
            BASE_IMAGE="python:3.11-slim"
        fi
    else
        echo "No NVIDIA GPU detected, using CPU image" >&2
        BASE_IMAGE="python:3.11-slim"
    fi
fi

echo "📦 Using base image: $BASE_IMAGE"
echo "🔨 Building service(s): $SERVICE"

# Export environment variables for build
export BASE_IMAGE
export BUILD_TYPE=prebuilt  # Use prebuilt by default (fastest)

# Build selected service(s) - use final-prebuilt target (default, fastest)
# Note: docker compose doesn't support --target, so we use docker build directly
cd "$PROJECT_ROOT"
CYREX_DIR="$PROJECT_ROOT/diri-cyrex"

# Convert WSL path to Windows path if using docker.exe
if [[ "$DOCKER_CMD" == "docker.exe" ]]; then
    # Convert /mnt/c/... to C:\...
    CYREX_DIR_WIN=$(echo "$CYREX_DIR" | sed 's|/mnt/\([a-z]\)|\1:|' | sed 's|/|\\|g')
    DOCKERFILE_WIN=$(echo "$CYREX_DIR/Dockerfile" | sed 's|/mnt/\([a-z]\)|\1:|' | sed 's|/|\\|g')
    DOCKERFILE_JUPYTER_WIN=$(echo "$CYREX_DIR/Dockerfile.jupyter" | sed 's|/mnt/\([a-z]\)|\1:|' | sed 's|/|\\|g')
else
    CYREX_DIR_WIN="$CYREX_DIR"
    DOCKERFILE_WIN="$CYREX_DIR/Dockerfile"
    DOCKERFILE_JUPYTER_WIN="$CYREX_DIR/Dockerfile.jupyter"
fi

case "$SERVICE" in
    cyrex)
        $DOCKER_CMD build \
            --target final-prebuilt \
            --build-arg BASE_IMAGE="$BASE_IMAGE" \
            --build-arg BUILD_TYPE="prebuilt" \
            --build-arg PYTORCH_VERSION="2.0.0" \
            --build-arg CUDA_VERSION="12.1" \
            --build-arg PYTHON_VERSION="3.11" \
            -f "$DOCKERFILE_WIN" \
            -t deepiri-dev-cyrex:latest \
            "$CYREX_DIR_WIN"
        ;;
    jupyter)
        $DOCKER_CMD build \
            --target final-prebuilt \
            --build-arg BASE_IMAGE="$BASE_IMAGE" \
            --build-arg BUILD_TYPE="prebuilt" \
            --build-arg PYTORCH_VERSION="2.0.0" \
            --build-arg CUDA_VERSION="12.1" \
            --build-arg PYTHON_VERSION="3.11" \
            -f "$DOCKERFILE_JUPYTER_WIN" \
            -t deepiri-dev-jupyter:latest \
            "$CYREX_DIR_WIN"
        ;;
    all|*)
        $DOCKER_CMD build \
            --target final-prebuilt \
            --build-arg BASE_IMAGE="$BASE_IMAGE" \
            --build-arg BUILD_TYPE="prebuilt" \
            --build-arg PYTORCH_VERSION="2.0.0" \
            --build-arg CUDA_VERSION="12.1" \
            --build-arg PYTHON_VERSION="3.11" \
            -f "$DOCKERFILE_WIN" \
            -t deepiri-dev-cyrex:latest \
            "$CYREX_DIR_WIN"
        $DOCKER_CMD build \
            --target final-prebuilt \
            --build-arg BASE_IMAGE="$BASE_IMAGE" \
            --build-arg BUILD_TYPE="prebuilt" \
            --build-arg PYTORCH_VERSION="2.0.0" \
            --build-arg CUDA_VERSION="12.1" \
            --build-arg PYTHON_VERSION="3.11" \
            -f "$DOCKERFILE_JUPYTER_WIN" \
            -t deepiri-dev-jupyter:latest \
            "$CYREX_DIR_WIN"
        ;;
esac

echo "✅ Build complete!"

