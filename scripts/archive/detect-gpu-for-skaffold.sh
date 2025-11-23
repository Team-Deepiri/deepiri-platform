#!/bin/bash
# GPU Detection for Skaffold
# Detects GPU and runs skaffold with appropriate profile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYREX_DIR="$SCRIPT_DIR/../diri-cyrex"
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "🔍 Detecting GPU and configuring environment..."

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

# Run the GPU detection script
if [ -f "$CYREX_DIR/detect_gpu.sh" ]; then
    BASE_IMAGE=$(bash "$CYREX_DIR/detect_gpu.sh")
    
    # Determine profile based on BASE_IMAGE
    if [[ "$BASE_IMAGE" == *"pytorch"* ]]; then
        PROFILE="gpu"
        echo "✅ GPU detected! Using GPU profile with: $BASE_IMAGE"
    else
        PROFILE="cpu"
        echo "ℹ️  No GPU or GPU below requirements. Using CPU profile with: $BASE_IMAGE"
    fi
    
    echo ""
    echo "Running: skaffold build --profile=$PROFILE"
    echo ""
    
    # Change to project root and run skaffold
    cd "$PROJECT_ROOT" || exit 1
    skaffold build --profile="$PROFILE" "$@"
else
    echo "Error: detect_gpu.sh not found at $CYREX_DIR/detect_gpu.sh"
    exit 1
fi

