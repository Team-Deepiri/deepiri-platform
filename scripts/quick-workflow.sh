#!/bin/bash

# Quick workflow script for building, running, and stopping containers

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if minikube docker-env is needed
if command -v minikube &> /dev/null; then
    if minikube status &> /dev/null; then
        print_info "Setting up Minikube Docker environment..."
        eval $(minikube docker-env)
    fi
fi

case "$1" in
    build)
        print_info "Building all images with Skaffold..."
        skaffold build -f skaffold-local.yaml -p dev-compose
        print_success "Build complete!"
        ;;
    
    run)
        print_info "Starting all containers..."
        docker compose -f docker-compose.dev.yml up -d
        print_success "Containers started!"
        print_info "View logs with: docker compose -f docker-compose.dev.yml logs -f"
        ;;
    
    stop)
        print_info "Stopping all containers..."
        docker compose -f docker-compose.dev.yml down
        print_success "Containers stopped!"
        ;;
    
    restart)
        print_info "Restarting all containers..."
        docker compose -f docker-compose.dev.yml down
        docker compose -f docker-compose.dev.yml up -d
        print_success "Containers restarted!"
        ;;
    
    rebuild)
        print_info "Rebuilding and restarting..."
        skaffold build -f skaffold-local.yaml -p dev-compose
        docker compose -f docker-compose.dev.yml down
        docker compose -f docker-compose.dev.yml up -d
        print_success "Rebuild and restart complete!"
        ;;
    
    clean)
        print_warning "This will remove all unused Docker images and free up space."
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cleaning up unused images..."
            docker system prune -a -f
            print_success "Cleanup complete!"
        else
            print_info "Cleanup cancelled."
        fi
        ;;
    
    status)
        print_info "Container status:"
        docker compose -f docker-compose.dev.yml ps
        ;;
    
    logs)
        docker compose -f docker-compose.dev.yml logs -f
        ;;
    
    *)
        echo "Usage: $0 {build|run|stop|restart|rebuild|clean|status|logs}"
        echo ""
        echo "Commands:"
        echo "  build   - Build all images with Skaffold"
        echo "  run     - Start all containers"
        echo "  stop    - Stop all containers"
        echo "  restart - Stop and start all containers"
        echo "  rebuild - Rebuild images and restart containers"
        echo "  clean   - Remove unused Docker images (frees space)"
        echo "  status  - Show container status"
        echo "  logs    - Follow logs from all containers"
        exit 1
        ;;
esac



