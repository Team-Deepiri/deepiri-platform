#!/bin/bash
# Simple 5-command workflow for Deepiri development
# Usage: ./BUILD_RUN_STOP.sh [build|run|logs|stop|rebuild]

set -e

COMMAND=$1

if [ -z "$COMMAND" ]; then
    echo "Usage: ./BUILD_RUN_STOP.sh [build|run|logs|stop|rebuild|status]"
    exit 1
fi

# Set Minikube Docker environment
eval $(minikube docker-env)

case $COMMAND in
    build)
        echo "🏗️  Building all services..."
        cd deepiri
        skaffold build -f skaffold/skaffold-local.yaml -p dev-compose
        echo "✅ Build complete! Images tagged with :latest (overwrites old ones)"
        ;;
    
    run)
        echo "🚀 Starting all services..."
        cd deepiri
        docker-compose -f docker-compose.dev.yml up -d
        echo "✅ All services running!"
        echo "💡 Use './BUILD_RUN_STOP.sh logs' to view logs"
        ;;
    
    logs)
        echo "📋 Viewing logs (Ctrl+C to exit)..."
        cd deepiri
        docker-compose -f docker-compose.dev.yml logs -f
        ;;
    
    stop)
        echo "🛑 Stopping all services..."
        cd deepiri
        docker-compose -f docker-compose.dev.yml down
        echo "✅ All services stopped!"
        ;;
    
    rebuild)
        echo "🔄 Rebuilding (this OVERWRITES existing images, no duplicates)..."
        cd deepiri
        
        # Stop services
        echo "  1/3 Stopping services..."
        docker-compose -f docker-compose.dev.yml down
        
        # Rebuild (will overwrite existing :latest tags)
        echo "  2/3 Rebuilding images..."
        skaffold build -f skaffold/skaffold-local.yaml -p dev-compose
        
        # Start services
        echo "  3/3 Starting services..."
        docker-compose -f docker-compose.dev.yml up -d
        
        echo "✅ Rebuild complete! Changes are now live."
        echo "💾 Storage used: Same as before (images overwritten, not duplicated)"
        ;;
    
    status)
        echo "📊 Docker Images:"
        docker images | grep "deepiri-dev"
        echo ""
        echo "📦 Running Containers:"
        cd deepiri
        docker-compose -f docker-compose.dev.yml ps
        ;;
    
    *)
        echo "❌ Unknown command: $COMMAND"
        echo "Usage: ./BUILD_RUN_STOP.sh [build|run|logs|stop|rebuild|status]"
        exit 1
        ;;
esac

