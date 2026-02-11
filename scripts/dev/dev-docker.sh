#!/bin/bash

# Deepiri Development Docker Environment
# This script manages the Docker development environment with HMR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
}

# Stop and remove existing containers
cleanup() {
    print_status "Cleaning up existing containers..."
    docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true
    docker system prune -f >/dev/null 2>&1 || true
    print_success "Cleanup completed"
}

# Build and start development environment
build_dev() {
    print_status "Starting Deepiri Development Environment..."
    
    # Kill any existing processes on port 5173
    print_status "Freeing up port 5173..."
    lsof -ti:5173 | xargs kill -9 2>/dev/null || true
    
    # Build and start services
    print_status "Building and starting services..."
    docker-compose -f docker-compose.dev.yml up -d --build
    
    print_success "Development environment started!"
    print_status "Services running:"
    echo "  Frontend (HMR): http://localhost:5173"
    echo "  Backend API:    http://localhost:5000"
    echo "  Agent:  http://localhost:8000"
    echo "  MongoDB:       localhost:27017"
    echo "  Redis:         localhost:6379"
    echo ""
    print_status "To view logs: docker-compose -f docker-compose.dev.yml logs -f frontend-dev"
    print_status "HMR should work automatically - edit files in ./client and see instant updates!"
}

# Start development environment
start_dev() {
    print_status "Starting Deepiri Development Environment..."
    
    # Kill any existing processes on port 5173
    print_status "Freeing up port 5173..."
    lsof -ti:5173 | xargs kill -9 2>/dev/null || true
    
    # Start services
    print_status "Starting services..."
    docker-compose -f docker-compose.dev.yml up -d 
    
    print_success "Development environment started!"
    print_status "Services running:"
    echo "  Frontend (HMR): http://localhost:5173"
    echo "  Backend API:    http://localhost:5000"
    echo "  Agent:  http://localhost:8000"
    echo "  MongoDB:       localhost:27017"
    echo "  Redis:         localhost:6379"
    echo ""
    print_status "To view logs: docker-compose -f docker-compose.dev.yml logs -f frontend-dev"
    print_status "HMR should work automatically - edit files in ./client and see instant updates!"
}

# Stop development environment
stop_dev() {
    print_status "Stopping development environment..."
    docker-compose -f docker-compose.dev.yml down
    print_success "Development environment stopped"
}

# Show logs
logs() {
    docker-compose -f docker-compose.dev.yml logs -f "${1:-frontend-dev}"
}

# Show status
status() {
    print_status "Development Environment Status:"
    docker-compose -f docker-compose.dev.yml ps
}

# Main script logic
case "${1:-start}" in
    "start")
        check_docker
        cleanup
        start_dev
        ;;
    "stop")
        stop_dev
        ;;
    "build")
        build_dev
        ;;
    "restart")
        stop_dev
        sleep 2
        check_docker
        start_dev
        ;;
    "rebuild")
        stop_dev
        sleep 2
        check_docker
        build_dev
        ;;
    "logs")
        logs "$2"
        ;;
    "status")
        status
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|cleanup}"
        echo ""
        echo "Commands:"
        echo "  start    - Start development environment with HMR"
        echo "  stop     - Stop development environment"
        echo "  restart  - Restart development environment"
        echo "  logs     - Show frontend logs (or specify service)"
        echo "  status   - Show container status"
        echo "  cleanup  - Clean up containers and volumes"
        echo ""
        echo "Examples:"
        echo "  $0 start              # Start dev environment"
        echo "  $0 logs frontend-dev  # Show frontend logs"
        echo "  $0 logs backend       # Show backend logs"
        exit 1
        ;;
esac
