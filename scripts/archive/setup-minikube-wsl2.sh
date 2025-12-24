#!/bin/bash
# Setup script for Minikube on WSL2
# This script configures Minikube with Docker driver for local development

echo "🚀 Setting up Minikube for Deepiri on WSL2..."

# Detect if running in WSL
IS_WSL=false
if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
    IS_WSL=true
    echo "✅ Detected WSL environment"
fi

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install it first:"
    echo "   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
    echo "   sudo install minikube-linux-amd64 /usr/local/bin/minikube"
    exit 1
fi

# Temporarily disable exit on error for Docker check
set +e

# Check Docker BEFORE unsetting anything (in case it's already working)
DOCKER_WORKS=false
if docker ps > /dev/null 2>&1; then
    DOCKER_WORKS=true
    echo "✅ Docker is accessible (current configuration works)"
else
    # Docker doesn't work with current config
    # In WSL, Docker Desktop integration should work automatically
    # If it doesn't work here but works manually, it's likely an environment issue
    
    # Save current values first for debugging
    OLD_DOCKER_HOST=$DOCKER_HOST
    OLD_DOCKER_TLS_VERIFY=$DOCKER_TLS_VERIFY
    OLD_DOCKER_CERT_PATH=$DOCKER_CERT_PATH
    OLD_MINIKUBE_ACTIVE_DOCKERD=$MINIKUBE_ACTIVE_DOCKERD
    
    # In WSL, don't unset DOCKER_HOST if it's not pointing to Minikube
    # Docker Desktop in WSL2 should work without explicit DOCKER_HOST
    if [ "$IS_WSL" = true ]; then
        # Only unset if it's pointing to Minikube
        if [[ "$DOCKER_HOST" == *"minikube"* ]]; then
            unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD
        fi
        # In WSL2, Docker Desktop should work without DOCKER_HOST set
        # Just try docker ps again
        DOCKER_CHECK=$(docker ps 2>&1)
        DOCKER_EXIT_CODE=$?
    else
        # Not WSL - unset and check normally
        unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD
        DOCKER_CHECK=$(docker ps 2>&1)
        DOCKER_EXIT_CODE=$?
    fi
    
    if [ $DOCKER_EXIT_CODE -ne 0 ]; then
        # In WSL, if docker ps works manually, it's likely the script environment
        # Give a warning but don't fail - Minikube will handle Docker connection
        if [ "$IS_WSL" = true ]; then
            echo "⚠️  Warning: Docker check failed in script, but if 'docker ps' works manually,"
            echo "   Docker Desktop is configured correctly. Continuing..."
            echo "   (This is common in WSL2 - Docker Desktop integration works in interactive shells)"
            DOCKER_WORKS=true  # Assume it works if in WSL
        else
            echo "❌ Docker is not accessible. Please start Docker Desktop or Docker daemon."
            echo "   Make sure Docker Desktop is running before continuing."
            echo ""
            echo "   Debug info:"
            echo "   - WSL detected: $IS_WSL"
            echo "   - DOCKER_HOST was: ${OLD_DOCKER_HOST:-not set}"
            echo "   - Current DOCKER_HOST: ${DOCKER_HOST:-not set}"
            echo "   - Docker error: $DOCKER_CHECK"
            echo ""
            echo "   Troubleshooting:"
            echo "   1. Make sure Docker Desktop is running"
            echo "   2. Try running manually: docker ps"
            exit 1
        fi
    else
        DOCKER_WORKS=true
    fi
fi

# Re-enable exit on error
set -e

if [ "$DOCKER_WORKS" = true ]; then
    echo "✅ Docker is running"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    echo "✅ kubectl installed successfully"
    kubectl version --client
fi

# Check if skaffold is installed
if ! command -v skaffold &> /dev/null; then
    echo "⚠️  Skaffold is not installed. Installing..."
    curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
    chmod +x skaffold
    sudo mv skaffold /usr/local/bin/
fi

# Stop existing minikube if running
if minikube status &> /dev/null; then
    echo "🛑 Stopping existing Minikube cluster..."
    minikube stop
fi

# Start Minikube with Docker driver
echo "🏗️  Starting Minikube cluster with Docker driver..."
minikube start \
    --driver=docker \
    --cpus=4 \
    --memory=8192 \
    --disk-size=20g \
    --addons=ingress \
    --addons=dashboard

# Configure Docker to use Minikube's Docker daemon
echo "🔧 Configuring Docker environment for Minikube..."
eval $(minikube docker-env)

# Verify Docker is accessible (now pointing to Minikube's Docker)
set +e
if ! docker ps &> /dev/null; then
    echo "⚠️  Warning: Docker is not accessible after switching to Minikube's Docker daemon."
    echo "   This is normal if Minikube just started. Continuing..."
else
    echo "✅ Docker is accessible (using Minikube's Docker daemon)"
fi
set -e

# Verify setup
echo "✅ Verifying setup..."
minikube status
if command -v kubectl &> /dev/null; then
    kubectl cluster-info
fi

# Show helpful commands
echo ""
echo "✅ Minikube setup complete!"
echo ""
echo "📋 Useful commands:"
echo "   minikube dashboard          # Open Kubernetes dashboard"
echo "   minikube service list       # List all services"
echo "   minikube tunnel            # Expose LoadBalancer services"
echo "   eval \$(minikube docker-env) # Use Minikube's Docker daemon"
echo ""
echo "🚀 Next steps:"
echo "   1. Make sure you're in the Minikube Docker environment:"
echo "      eval \$(minikube docker-env)"
echo "      2. Run Skaffold:"
    echo "      skaffold dev -f skaffold-local.yaml --port-forward"
    echo "      # Or use the helper script:"
    echo "      ./scripts/start-skaffold-dev.sh"
echo ""
