#!/bin/bash
# Simplified Skaffold build script with auto GPU detection
# Usage: ./scripts/skaffold-build.sh [cpu|gpu|auto]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CYREX_DIR="$PROJECT_ROOT/diri-cyrex"

# Get profile from argument or auto-detect
PROFILE="${1:-auto}"

# Change to project root
cd "$PROJECT_ROOT" || exit 1

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "⚠️  Minikube is not running. Starting Minikube..."
    minikube start --driver=docker --cpus=4 --memory=8192
fi

# Configure Docker to use Minikube's Docker daemon
echo "🔧 Configuring Docker environment for Minikube..."
eval $(minikube docker-env)

# Verify Docker is accessible
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not accessible after switching to Minikube's Docker daemon."
    echo "   Try running: minikube start"
    exit 1
fi
echo "✅ Docker is accessible (using Minikube's Docker daemon)"

# Auto-detect GPU if profile is "auto"
if [ "$PROFILE" = "auto" ]; then
    echo "🔍 Auto-detecting GPU..."
    
    if [ -f "$CYREX_DIR/detect_gpu.sh" ]; then
        BASE_IMAGE=$(bash "$CYREX_DIR/detect_gpu.sh")
        
        if [[ "$BASE_IMAGE" == *"pytorch"* ]]; then
            PROFILE="gpu"
            echo "✅ NVIDIA GPU detected! Using GPU profile"
        else
            PROFILE="cpu"
            echo "ℹ️  No NVIDIA GPU or GPU below requirements. Using CPU profile"
            echo "   (Intel Iris Xe and other integrated GPUs use CPU profile)"
        fi
    else
        # Fallback: check for nvidia-smi
        if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
            GPU_MEMORY_GB=$((GPU_MEMORY / 1024))
            if [ "$GPU_MEMORY_GB" -ge 4 ]; then
                PROFILE="gpu"
                echo "✅ NVIDIA GPU detected (${GPU_MEMORY_GB}GB)! Using GPU profile"
            else
                PROFILE="cpu"
                echo "ℹ️  NVIDIA GPU memory (${GPU_MEMORY_GB}GB) below minimum (4GB). Using CPU profile"
            fi
        else
            PROFILE="cpu"
            echo "ℹ️  No NVIDIA GPU detected. Using CPU profile"
        fi
    fi
fi

# Validate profile
if [ "$PROFILE" != "cpu" ] && [ "$PROFILE" != "gpu" ]; then
    echo "❌ Invalid profile: $PROFILE"
    echo "   Use: cpu, gpu, or auto (default)"
    exit 1
fi

echo ""
echo "🚀 Building all services with Skaffold (profile: $PROFILE)"
echo ""

# Run skaffold build
skaffold build --profile="$PROFILE" "$@"

echo ""
echo "✅ Build complete! All services built with profile: $PROFILE"
echo ""
echo "To deploy: skaffold dev --profile=$PROFILE"
echo "Or: skaffold run --profile=$PROFILE"

