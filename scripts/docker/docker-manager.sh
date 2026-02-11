#!/bin/bash

# tripblip MAG 2.0 - Docker Management Scripts
# Comprehensive Docker utilities for development and production

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="deepiri"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Check if .env file exists
check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env file not found. Creating from env.example..."
        if [ -f "env.example" ]; then
            cp env.example "$ENV_FILE"
            log_info "Please update the .env file with your configuration."
        else
            log_error "env.example file not found. Please create a .env file."
            exit 1
        fi
    fi
}

# Build all services
build_all() {
    log_info "Building all services..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    log_success "All services built successfully!"
}

# Start all services
start_all() {
    log_info "Starting all services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    log_success "All services started successfully!"
}

# Stop all services
stop_all() {
    log_info "Stopping all services..."
    docker-compose -f "$COMPOSE_FILE" down
    log_success "All services stopped successfully!"
}

# Restart all services
restart_all() {
    log_info "Restarting all services..."
    docker-compose -f "$COMPOSE_FILE" restart
    log_success "All services restarted successfully!"
}

# Show logs for all services
logs_all() {
    docker-compose -f "$COMPOSE_FILE" logs -f --tail=100
}

# Show logs for specific service
logs_service() {
    local service=$1
    if [ -z "$service" ]; then
        log_error "Please specify a service name"
        exit 1
    fi
    docker-compose -f "$COMPOSE_FILE" logs -f --tail=100 "$service"
}

# Show status of all services
status_all() {
    log_info "Service Status:"
    docker-compose -f "$COMPOSE_FILE" ps
}

# Clean up Docker resources
cleanup() {
    log_info "Cleaning up Docker resources..."
    
    # Stop and remove containers
    docker-compose -f "$COMPOSE_FILE" down -v
    
    # Remove unused images
    docker image prune -f
    
    # Remove unused volumes
    docker volume prune -f
    
    # Remove unused networks
    docker network prune -f
    
    log_success "Cleanup completed!"
}

# Reset everything (nuclear option)
reset_all() {
    log_warning "This will remove ALL Docker resources. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log_info "Resetting everything..."
        
        # Stop and remove all containers
        docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
        
        # Remove all images
        docker rmi $(docker images -q) 2>/dev/null || true
        
        # Remove all volumes
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        
        # Remove all networks
        docker network rm $(docker network ls -q) 2>/dev/null || true
        
        log_success "Complete reset completed!"
    else
        log_info "Reset cancelled."
    fi
}

# Health check for all services
health_check() {
    log_info "Performing health checks..."
    
    local services=("backend" "cyrex" "deepiri-web-frontend" "mongodb" "redis")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        log_success "All services are healthy!"
    else
        log_error "Some services are not healthy!"
        exit 1
    fi
}

# Database backup
backup_database() {
    local backup_file="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log_info "Creating database backup: $backup_file"
    
    docker-compose -f "$COMPOSE_FILE" exec mongodb mongodump --out /backup
    docker-compose -f "$COMPOSE_FILE" exec mongodb tar -czf "/backup/$backup_file" /backup/deepiri
    docker cp "$(docker-compose -f "$COMPOSE_FILE" ps -q mongodb):/backup/$backup_file" "./$backup_file"
    
    log_success "Database backup created: $backup_file"
}

# Database restore
restore_database() {
    local backup_file=$1
    if [ -z "$backup_file" ]; then
        log_error "Please specify a backup file"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_info "Restoring database from: $backup_file"
    
    docker cp "$backup_file" "$(docker-compose -f "$COMPOSE_FILE" ps -q mongodb):/backup/"
    docker-compose -f "$COMPOSE_FILE" exec mongodb tar -xzf "/backup/$backup_file" -C /
    docker-compose -f "$COMPOSE_FILE" exec mongodb mongorestore /backup/deepiri
    
    log_success "Database restored successfully!"
}

# Development setup
dev_setup() {
    log_info "Setting up development environment..."
    
    # Create necessary directories
    mkdir -p logs
    mkdir -p data/mongodb
    mkdir -p data/redis
    
    # Set proper permissions
    chmod 755 logs
    chmod 755 data
    
    # Install dependencies
    log_info "Installing Node.js dependencies..."
    npm install
    
    log_info "Installing API server dependencies..."
    cd deepiri-core-api && npm install && cd ..
    
    log_info "Installing deepiri-web-frontend dependencies..."
    cd deepiri-web-frontend && npm install && cd ..
    
    log_info "Installing Python dependencies..."
    cd diri-cyrex && pip install -r requirements.txt && cd ..
    
    log_success "Development environment setup completed!"
}

# Production deployment
prod_deploy() {
    log_info "Deploying to production..."
    
    # Build production images
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    
    # Start services
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be ready
    sleep 30
    
    # Health check
    health_check
    
    log_success "Production deployment completed!"
}

# Monitor resources
monitor_resources() {
    log_info "Monitoring Docker resources..."
    
    echo "=== Container Resource Usage ==="
    docker stats --no-stream
    
    echo ""
    echo "=== Disk Usage ==="
    docker system df
    
    echo ""
    echo "=== Volume Usage ==="
    docker volume ls
}

# Update all images
update_images() {
    log_info "Updating all Docker images..."
    
    docker-compose -f "$COMPOSE_FILE" pull
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    
    log_success "All images updated!"
}

# Show help
show_help() {
    echo "tripblip MAG 2.0 - Docker Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build          Build all services"
    echo "  start          Start all services"
    echo "  stop           Stop all services"
    echo "  restart        Restart all services"
    echo "  logs           Show logs for all services"
    echo "  logs [service] Show logs for specific service"
    echo "  status         Show status of all services"
    echo "  health         Perform health checks"
    echo "  cleanup        Clean up Docker resources"
    echo "  reset          Reset everything (nuclear option)"
    echo "  backup         Backup database"
    echo "  restore [file] Restore database from backup"
    echo "  dev-setup      Setup development environment"
    echo "  prod-deploy    Deploy to production"
    echo "  monitor        Monitor resource usage"
    echo "  update         Update all images"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs backend"
    echo "  $0 restore backup_20240101_120000.tar.gz"
}

# Main script logic
main() {
    check_docker
    check_env
    
    case "${1:-help}" in
        build)
            build_all
            ;;
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        logs)
            if [ -n "$2" ]; then
                logs_service "$2"
            else
                logs_all
            fi
            ;;
        status)
            status_all
            ;;
        health)
            health_check
            ;;
        cleanup)
            cleanup
            ;;
        reset)
            reset_all
            ;;
        backup)
            backup_database
            ;;
        restore)
            restore_database "$2"
            ;;
        dev-setup)
            dev_setup
            ;;
        prod-deploy)
            prod_deploy
            ;;
        monitor)
            monitor_resources
            ;;
        update)
            update_images
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
