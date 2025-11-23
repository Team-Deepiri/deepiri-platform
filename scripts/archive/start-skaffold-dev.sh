#!/bin/bash
# Start Deepiri development environment with Skaffold
# This script ensures proper environment setup before running Skaffold

set -e

echo "🚀 Starting Deepiri with Skaffold..."

# Detect if running in WSL
if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
    IS_WSL=true
    echo "✅ Detected WSL environment"
else
    IS_WSL=false
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Starting Minikube..."
    minikube start --driver=docker --cpus=4 --memory=8192
fi

# Temporarily disable exit on error for Docker check
set +e

# Unset Minikube Docker env if set (to check host Docker first)
OLD_DOCKER_HOST=$DOCKER_HOST
unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD

# For WSL2 with Docker Desktop, try to connect via Windows host
if [ "$IS_WSL" = true ]; then
    # Get Windows host IP (usually in /etc/resolv.conf nameserver)
    WINDOWS_HOST=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1)
    if [ -n "$WINDOWS_HOST" ]; then
        export DOCKER_HOST="tcp://${WINDOWS_HOST}:2375"
    fi
fi

# Check if host Docker is running (before switching to Minikube's Docker)
# Use docker ps (works even if docker info fails)
DOCKER_CHECK=$(docker ps 2>&1)
DOCKER_EXIT_CODE=$?

if [ $DOCKER_EXIT_CODE -ne 0 ]; then
    # If WSL and first attempt failed, try without DOCKER_HOST
    if [ "$IS_WSL" = true ] && [ -n "$DOCKER_HOST" ]; then
        unset DOCKER_HOST
        DOCKER_CHECK=$(docker ps 2>&1)
        DOCKER_EXIT_CODE=$?
    fi
    
    if [ $DOCKER_EXIT_CODE -ne 0 ]; then
        echo "❌ Host Docker is not accessible. Please start Docker Desktop or Docker daemon."
        echo ""
        echo "   Debug info:"
        echo "   - WSL detected: $IS_WSL"
        echo "   - DOCKER_HOST was: ${OLD_DOCKER_HOST:-not set}"
        echo "   - Docker error: $DOCKER_CHECK"
        echo ""
        echo "   Troubleshooting:"
        echo "   1. Make sure Docker Desktop is running on Windows"
        echo "   2. In Docker Desktop: Settings > General > Use the WSL 2 based engine"
        echo "   3. In Docker Desktop: Settings > Resources > WSL Integration > Enable integration"
        echo "   4. Try running manually: docker ps"
        exit 1
    fi
fi

# Re-enable exit on error
set -e

echo "✅ Docker is accessible"

# Configure Docker to use Minikube's Docker daemon
echo "🔧 Configuring Docker environment for Minikube..."
eval $(minikube docker-env)

# Verify Docker is pointing to Minikube (give it a moment if Minikube just started)
echo "⏳ Verifying Docker connection to Minikube..."
sleep 2
if ! docker ps &> /dev/null; then
    echo "⚠️  Warning: Docker not immediately accessible. Retrying..."
    sleep 3
    if ! docker ps &> /dev/null; then
        echo "❌ Docker is not accessible after switching to Minikube's Docker daemon."
        echo "   Try running: minikube start"
        exit 1
    fi
fi
echo "✅ Docker is accessible (using Minikube's Docker daemon)"

# Check if skaffold is installed
if ! command -v skaffold &> /dev/null; then
    echo "❌ Skaffold is not installed. Please install it first."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "skaffold-local.yaml" ] && [ ! -f "skaffold.yaml" ]; then
    echo "❌ skaffold-local.yaml or skaffold.yaml not found. Please run this script from the project root."
    exit 1
fi

# Check if k8s manifests exist
if [ ! -d "ops/k8s" ]; then
    echo "❌ Kubernetes manifests not found in ops/k8s/"
    exit 1
fi

# Configure kubectl to use Minikube context
echo "🔧 Configuring kubectl for Minikube..."
if command -v kubectl &> /dev/null; then
    # Set kubectl context to minikube
    kubectl config use-context minikube &> /dev/null || {
        echo "⚠️  Warning: Could not set kubectl context to minikube automatically"
        echo "   Trying to get kubeconfig from minikube..."
        minikube update-context &> /dev/null || true
    }
    
    # Verify kubectl can connect
    if ! kubectl cluster-info &> /dev/null; then
        echo "⚠️  Warning: kubectl cannot connect to cluster. Trying to fix..."
        minikube update-context
        sleep 2
        if ! kubectl cluster-info &> /dev/null; then
            echo "❌ kubectl cannot connect to Minikube cluster."
            echo "   Try running: minikube start"
            exit 1
        fi
    fi
    echo "✅ kubectl is configured and can connect to Minikube"
else
    echo "⚠️  Warning: kubectl is not installed. Skaffold may have issues connecting to Kubernetes."
fi

# Unset any in-cluster config environment variables that might interfere
unset KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT

# Ensure KUBECONFIG is set (Skaffold will use this instead of in-cluster config)
if [ -z "$KUBECONFIG" ]; then
    export KUBECONFIG="$HOME/.kube/config"
fi

# Use skaffold-local.yaml for local development
CONFIG_FILE="skaffold-local.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  Warning: $CONFIG_FILE not found, falling back to skaffold.yaml"
    CONFIG_FILE="skaffold.yaml"
fi

echo "✅ Environment ready. Starting Skaffold (DEV mode)..."
echo ""
echo "📋 Skaffold will:"
echo "   - Use config: $CONFIG_FILE"
echo "   - Build Docker images using Minikube's Docker daemon"
echo "   - Deploy to Kubernetes"
echo "   - Auto-sync files for faster development"
echo "   - Port-forward services automatically"
echo "   - Stream logs"
echo ""
echo "Press Ctrl+C to stop and cleanup..."
echo ""

# Run Skaffold in dev mode
skaffold dev \
    -f "$CONFIG_FILE" \
    --port-forward \
    --trigger=notify \
    --watch-poll=1000 \
    --default-repo=localhost:5000

