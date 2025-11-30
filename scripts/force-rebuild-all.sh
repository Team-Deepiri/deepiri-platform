#!/bin/bash

# Rebuild all images with Docker (bypasses Skaffold cache loop)
# Use --no-cache flag to force complete rebuild, otherwise uses cache

set -e

# Check if --no-cache flag was passed
NO_CACHE=""
if [ "$1" = "--no-cache" ] || [ "$1" = "-n" ]; then
    NO_CACHE="--no-cache"
    echo "🔨 Force rebuilding ALL images with --no-cache..."
    echo "This bypasses Docker's cache and forces a complete rebuild"
else
    echo "🔨 Rebuilding ALL images (using Docker cache)..."
    echo "Add --no-cache flag to force complete rebuild"
fi
echo ""

# Point Docker to Minikube
eval $(minikube docker-env)

# Function to build and tag an image
build_image() {
    local image_name=$1
    local context=$2
    local dockerfile=$3
    shift 3
    local build_args=("$@")
    
    echo "📦 Building $image_name..."
    
    # Extract --target flag if present
    local target_flag=""
    for arg in "${build_args[@]}"; do
        if [[ "$arg" == "--target" ]]; then
            target_flag="--target"
        elif [[ -n "$target_flag" ]]; then
            target_flag="$target_flag $arg"
            break
        fi
    done
    
    docker build \
        $NO_CACHE \
        $target_flag \
        -t "$image_name:latest" \
        -f "$context/$dockerfile" \
        "${build_args[@]}" \
        "$context"
    echo "✅ Built $image_name:latest"
    echo ""
}

# Build all services
build_image "deepiri-dev-cyrex" \
    "./diri-cyrex" \
    "Dockerfile" \
    --build-arg BUILD_TYPE=prebuilt \
    --build-arg BASE_IMAGE=python:3.11-slim \
    --build-arg PYTORCH_VERSION=2.9.1 \
    --build-arg PYTHON_VERSION=3.11

build_image "deepiri-dev-jupyter" \
    "./diri-cyrex" \
    "Dockerfile.jupyter" \
    --build-arg BUILD_TYPE=prebuilt \
    --build-arg BASE_IMAGE=python:3.11-slim \
    --build-arg PYTORCH_VERSION=2.9.1 \
    --build-arg PYTHON_VERSION=3.11 \
    --target base-prebuilt

build_image "deepiri-dev-frontend" \
    "./deepiri-web-frontend" \
    "Dockerfile.dev"

build_image "deepiri-dev-api-gateway" \
    "./platform-services" \
    "backend/deepiri-api-gateway/Dockerfile"

build_image "deepiri-dev-auth-service" \
    "./platform-services" \
    "backend/deepiri-auth-service/Dockerfile"

build_image "deepiri-dev-task-orchestrator" \
    "./platform-services" \
    "backend/deepiri-task-orchestrator/Dockerfile"

build_image "deepiri-dev-challenge-service" \
    "./platform-services" \
    "backend/deepiri-challenge-service/Dockerfile"

build_image "deepiri-dev-engagement-service" \
    "./platform-services" \
    "backend/deepiri-engagement-service/Dockerfile"

build_image "deepiri-dev-platform-analytics-service" \
    "./platform-services" \
    "backend/deepiri-platform-analytics-service/Dockerfile"

build_image "deepiri-dev-external-bridge-service" \
    "./platform-services" \
    "backend/deepiri-external-bridge-service/Dockerfile"

build_image "deepiri-dev-notification-service" \
    "./platform-services" \
    "backend/deepiri-notification-service/Dockerfile"

build_image "deepiri-dev-realtime-gateway" \
    "./platform-services" \
    "backend/deepiri-realtime-gateway/Dockerfile"

if [ -n "$NO_CACHE" ]; then
    echo "✅ All images rebuilt with --no-cache!"
else
    echo "✅ All images rebuilt (using cache where possible)!"
fi
echo ""
echo "🧹 Cleaning up old image tags..."
bash "$(dirname "$0")/cleanup-old-image-tags.sh" || true
echo ""
echo "Now run: docker compose -f docker-compose.dev.yml up -d"


