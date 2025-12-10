#!/bin/bash
# Hybrid workflow: Build with Skaffold, Run with Docker Compose
# This gives you the best of both worlds:
# - Skaffold builds using Minikube's Docker daemon (consistent with K8s)
# - Docker Compose runs containers (fastest startup)

set -e

echo "🔨 Hybrid Workflow: Build with Skaffold, Run with Docker Compose"
echo ""

# Step 1: Check prerequisites
echo "📋 Step 1: Checking prerequisites..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed."
    echo "   Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    echo "✅ kubectl installed"
else
    echo "✅ kubectl is installed"
    kubectl version --client
fi

# Check Minikube
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install it first."
    exit 1
fi

# Check if Minikube is running
if ! minikube status &> /dev/null; then
    echo "⚠️  Minikube is not running. Starting Minikube..."
    minikube start --driver=docker --cpus=4 --memory=8192
else
    echo "✅ Minikube is running"
    minikube status
fi

# Check Skaffold
if ! command -v skaffold &> /dev/null; then
    echo "❌ Skaffold is not installed. Please install it first."
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install it first."
    exit 1
fi

echo ""
echo "✅ All prerequisites met!"
echo ""

# Step 2: Configure Docker to use Minikube's Docker daemon
echo "📋 Step 2: Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env)

# Verify Docker is pointing to Minikube
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not accessible after switching to Minikube's Docker daemon."
    echo "   Try running: minikube start"
    exit 1
fi

echo "✅ Docker is using Minikube's Docker daemon"
echo ""

# Step 3: Build with Skaffold
echo "📋 Step 3: Building images with Skaffold..."
echo "   This builds images in Minikube's Docker daemon (consistent with K8s)"
echo "   Using 'dev-compose' profile to build images with Docker Compose naming"
echo ""

CONFIG_FILE="skaffold-local.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  $CONFIG_FILE not found, falling back to skaffold.yaml"
    CONFIG_FILE="skaffold.yaml"
fi

# Use dev-compose profile to build images with names Docker Compose expects
skaffold build -f "$CONFIG_FILE" -p dev-compose

if [ $? -ne 0 ]; then
    echo "❌ Skaffold build failed"
    exit 1
fi

echo ""
echo "✅ Images built successfully!"
echo ""

# Step 3.5: Tag images with :latest (Skaffold tags with commit hashes)
echo "📋 Step 3.5: Tagging images with :latest for Docker Compose..."
echo "   Skaffold tags images with commit hashes, but Docker Compose expects :latest"
echo ""

IMAGES=(
    "deepiri-dev-cyrex"
    "deepiri-dev-frontend"
    "deepiri-dev-api-gateway"
    "deepiri-dev-auth-service"
    "deepiri-dev-task-orchestrator"
    "deepiri-dev-challenge-service"
    "deepiri-dev-engagement-service"
    "deepiri-dev-platform-analytics-service"
    "deepiri-dev-external-bridge-service"
    "deepiri-dev-notification-service"
    "deepiri-dev-realtime-gateway"
)

TAGGED=0
for img in "${IMAGES[@]}"; do
    # Find the image with any tag (excluding :latest if it exists)
    SOURCE_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${img}:" | grep -v ":latest$" | head -1)
    
    if [ -n "$SOURCE_IMAGE" ]; then
        TARGET="${img}:latest"
        docker tag "$SOURCE_IMAGE" "$TARGET" 2>/dev/null && {
            echo "   ✅ Tagged: $SOURCE_IMAGE -> $TARGET"
            TAGGED=$((TAGGED + 1))
        } || echo "   ⚠️  Failed to tag: $SOURCE_IMAGE"
    else
        # Check if :latest already exists
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}:latest$"; then
            echo "   ✅ Already tagged: ${img}:latest"
        else
            echo "   ⚠️  Image not found: $img"
        fi
    fi
done

if [ $TAGGED -gt 0 ]; then
    echo "   ✅ Tagged $TAGGED images with :latest!"
else
    echo "   ⚠️  No new images tagged (checking if :latest tags exist)..."
fi

echo ""

# Step 4: Keep using Minikube's Docker daemon (images are already there!)
echo "📋 Step 4: Keeping Docker pointing to Minikube's Docker daemon..."
echo "   This allows Docker Compose to use the images Skaffold just built"
echo "   (No need to switch - images are already in Minikube's Docker)"
echo ""

# Verify Docker is still accessible
if ! docker ps &> /dev/null; then
    echo "⚠️  Warning: Docker is not accessible. Reconfiguring..."
    eval $(minikube docker-env)
fi

echo "✅ Docker is using Minikube's Docker daemon (images available)"
echo ""

# Step 4.5: Cleanup old image tags (save storage)
echo "🧹 Step 4.5: Cleaning up old image tags (saving storage)..."
if [ -f "$(dirname "$0")/cleanup-old-image-tags.sh" ]; then
    bash "$(dirname "$0")/cleanup-old-image-tags.sh" || echo "⚠️  Cleanup had warnings, continuing..."
else
    echo "⚠️  Cleanup script not found, skipping..."
fi
echo ""

# Step 5: Run with Docker Compose (fastest!)
echo "📋 Step 5: Starting services with Docker Compose (fastest!)..."
echo ""

COMPOSE_FILE="docker-compose.dev.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ $COMPOSE_FILE not found"
    exit 1
fi

# Determine compose command
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Start services
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Services started with Docker Compose!"
    echo ""
    echo "📋 Useful commands:"
    echo "   View logs:        $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
    echo "   View status:      $COMPOSE_CMD -f $COMPOSE_FILE ps"
    echo "   Stop services:    $COMPOSE_CMD -f $COMPOSE_FILE down"
    echo ""
    echo "🌐 Services available:"
    echo "   Backend API:      http://localhost:5000"
    echo "   Cyrex AI:         http://localhost:8000"
    echo "   MongoDB:          localhost:27017"
    echo "   Redis:            localhost:6379"
    echo ""
    echo "💡 Note: Images were built with Minikube's Docker daemon"
    echo "   but are running with Docker Compose (fastest startup!)"
    echo ""
else
    echo "❌ Failed to start services"
    exit 1
fi

