#!/bin/bash
# Quick start script for Docker Compose (fastest way to run pre-built containers)

echo "🚀 Starting Deepiri with Docker Compose (fast mode)..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install it first."
    exit 1
fi

# Determine compose command
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

COMPOSE_FILE="docker-compose.dev.yml"

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ $COMPOSE_FILE not found. Please run this script from the project root."
    exit 1
fi

# CRITICAL: Check if Minikube is running and use its Docker daemon
if command -v minikube &> /dev/null; then
    if minikube status &> /dev/null; then
        echo "📋 Minikube is running - using Minikube's Docker daemon (where Skaffold builds images)"
        eval $(minikube docker-env)
        echo "✅ Docker is now pointing to Minikube's Docker daemon"
    else
        echo "⚠️  Minikube is not running - using host Docker daemon"
    fi
fi

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop or Docker daemon."
    exit 1
fi

echo "✅ Docker is running"
echo ""
echo "📋 Starting services (using existing images - fast!)..."
echo "   This will NOT rebuild images - uses pre-built containers"
echo ""

# Start services
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Services started!"
    echo ""
    echo "📋 Useful commands:"
    echo "   View logs:        $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
    echo "   View status:      $COMPOSE_CMD -f $COMPOSE_FILE ps"
    echo "   Stop services:    $COMPOSE_CMD -f $COMPOSE_FILE down"
    echo "   Restart service:  $COMPOSE_CMD -f $COMPOSE_FILE restart <service-name>"
    echo ""
    echo "🌐 Services available:"
    echo "   Backend API:      http://localhost:5000"
    echo "   Cyrex AI:         http://localhost:8000"
    echo "   MongoDB:          localhost:27017"
    echo "   Redis:            localhost:6379"
    echo "   Mongo Express:    http://localhost:8081"
    echo ""
else
    echo "❌ Failed to start services"
    exit 1
fi

