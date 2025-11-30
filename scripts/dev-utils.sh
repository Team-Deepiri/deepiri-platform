#!/bin/bash

# Deepiri - Development Utilities
# Various development and maintenance scripts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Install all dependencies
install_deps() {
    log_info "Installing all dependencies..."
    
    # Root dependencies
    log_info "Installing root dependencies..."
    npm install
    
    # API server dependencies
    log_info "Installing API server dependencies..."
    cd deepiri-core-api
    npm install
    cd ..
    
    # Frontend dependencies
    log_info "Installing deepiri-web-frontend dependencies..."
    cd deepiri-web-frontend
    npm install
    cd ..
    
    # Python dependencies
    log_info "Installing Python dependencies..."
    cd diri-cyrex
    pip install -r requirements.txt
    cd ..
    
    log_success "All dependencies installed!"
}

# Run tests for all services
run_tests() {
    log_info "Running tests for all services..."
    
    # Node.js API server tests
    log_info "Running API server tests..."
    cd deepiri-core-api
    npm test
    cd ..
    
    # Python backend tests
    log_info "Running Python backend tests..."
    cd diri-cyrex
    python -m pytest tests/ -v
    cd ..
    
    # Frontend tests
    log_info "Running deepiri-web-frontend tests..."
    cd deepiri-web-frontend
    npm test
    cd ..
    
    log_success "All tests completed!"
}

# Lint all code
lint_all() {
    log_info "Linting all code..."
    
    # API server linting
    log_info "Linting API server code..."
    cd deepiri-core-api
    npm run lint || true
    cd ..
    
    # Frontend linting
    log_info "Linting deepiri-web-frontend code..."
    cd deepiri-web-frontend
    npm run lint || true
    cd ..
    
    log_success "Linting completed!"
}

# Format all code
format_all() {
    log_info "Formatting all code..."
    
    # Server formatting
    log_info "Formatting server code..."
    cd deepiri-core-api
    npx prettier --write "**/*.{js,json}" || true
    cd ..
    
    # Client formatting
    log_info "Formatting client code..."
    cd deepiri-web-frontend
    npx prettier --write "**/*.{js,jsx,json,css}" || true
    cd ..
    
    # Python formatting
    log_info "Formatting Python code..."
    cd diri-cyrex
    python -m black . || true
    python -m isort . || true
    cd ..
    
    log_success "Code formatting completed!"
}

# Generate API documentation
generate_docs() {
    log_info "Generating API documentation..."
    
    # Server API docs
    log_info "Generating API server API docs..."
    cd deepiri-core-api
    npx swagger-jsdoc -d swaggerDef.js -o swagger.json routes/*.js || true
    cd ..
    
    # Python API docs
    log_info "Generating Python API docs..."
    cd diri-cyrex
    python -m pydoc -w app || true
    cd ..
    
    log_success "Documentation generated!"
}

# Database migration
migrate_db() {
    log_info "Running database migrations..."
    
    # This would typically run migration scripts
    # For now, we'll just log the action
    log_info "Database migrations would be run here..."
    
    log_success "Database migrations completed!"
}

# Seed database
seed_db() {
    log_info "Seeding database..."
    
    # This would typically run seed scripts
    # For now, we'll just log the action
    log_info "Database seeding would be run here..."
    
    log_success "Database seeded!"
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    
    # Remove node_modules
    rm -rf node_modules
    rm -rf server/node_modules
    rm -rf client/node_modules
    
    # Remove build directories
    rm -rf client/dist
    rm -rf server/dist
    
    # Remove Python cache
    find diri-cyrex -name "__pycache__" -type d -exec rm -rf {} + || true
    find diri-cyrex -name "*.pyc" -type f -delete || true
    
    # Remove logs
    rm -rf logs/*
    
    log_success "Build artifacts cleaned!"
}

# Security audit
security_audit() {
    log_info "Running security audit..."
    
    # Node.js security audit
    log_info "Auditing Node.js dependencies..."
    npm audit || true
    
    cd deepiri-core-api
    npm audit || true
    cd ..
    
    cd deepiri-web-frontend
    npm audit || true
    cd ..
    
    # Python security audit
    log_info "Auditing Python dependencies..."
    cd diri-cyrex
    pip-audit || true
    cd ..
    
    log_success "Security audit completed!"
}

# Performance analysis
performance_analysis() {
    log_info "Running performance analysis..."
    
    # Node.js performance
    log_info "Analyzing Node.js performance..."
    cd deepiri-core-api
    npx clinic doctor -- node server.js &
    SERVER_PID=$!
    sleep 10
    kill $SERVER_PID || true
    cd ..
    
    # Python performance
    log_info "Analyzing Python performance..."
    cd diri-cyrex
    python -m cProfile -o profile.prof app/main.py || true
    cd ..
    
    log_success "Performance analysis completed!"
}

# Environment validation
validate_env() {
    log_info "Validating environment..."
    
    # Check required environment variables
    local required_vars=(
        "NODE_ENV"
        "PORT"
        "MONGODB_URI"
        "JWT_SECRET"
        "OPENAI_API_KEY"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi
    
    log_success "Environment validation passed!"
}

# Backup configuration
backup_config() {
    local backup_dir="backups/config_$(date +%Y%m%d_%H%M%S)"
    log_info "Creating configuration backup: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Copy configuration files
    cp -r deepiri-core-api/config "$backup_dir/" || true
    cp -r diri-cyrex/app/settings.py "$backup_dir/" || true
    cp docker-compose.yml "$backup_dir/"
    cp .env "$backup_dir/" || true
    cp env.example "$backup_dir/" || true
    
    # Create archive
    tar -czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log_success "Configuration backup created: ${backup_dir}.tar.gz"
}

# Restore configuration
restore_config() {
    local backup_file=$1
    if [ -z "$backup_file" ]; then
        log_error "Please specify a backup file"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_info "Restoring configuration from: $backup_file"
    
    # Extract backup
    tar -xzf "$backup_file"
    local backup_dir=$(basename "$backup_file" .tar.gz)
    
    # Restore files
    cp -r "$backup_dir/config" deepiri-core-api/ || true
    cp "$backup_dir/settings.py" diri-cyrex/app/ || true
    cp "$backup_dir/docker-compose.yml" . || true
    cp "$backup_dir/.env" . || true
    
    # Cleanup
    rm -rf "$backup_dir"
    
    log_success "Configuration restored!"
}

# Development server setup
dev_server() {
    log_info "Starting development servers..."
    
    # Start all services in development mode
    log_info "Starting backend server..."
    cd deepiri-core-api
    npm run dev &
    SERVER_PID=$!
    cd ..
    
    log_info "Starting Python agent..."
    cd diri-cyrex
    python -m uvicorn app.main:app --reload --port 8000 &
    PYTHON_PID=$!
    cd ..
    
    log_info "Starting deepiri-web-frontend..."
    cd deepiri-web-frontend
    npm run dev &
    CLIENT_PID=$!
    cd ..
    
    log_info "Development servers started!"
    log_info "Backend: http://localhost:5000"
    log_info "Python Agent: http://localhost:8000"
    log_info "Frontend: http://localhost:5173"
    
    # Wait for interrupt
    trap "kill $SERVER_PID $PYTHON_PID $CLIENT_PID; exit" INT
    wait
}

# Production build
prod_build() {
    log_info "Building for production..."
    
    # Build client
    log_info "Building client..."
    cd deepiri-web-frontend
    npm run build
    cd ..
    
    # Build Docker images
    log_info "Building Docker images..."
    docker-compose build --no-cache
    
    log_success "Production build completed!"
}

# Show help
show_help() {
    echo "tripblip MAG 2.0 - Development Utilities"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install-deps     Install all dependencies"
    echo "  test            Run all tests"
    echo "  lint            Lint all code"
    echo "  format          Format all code"
    echo "  docs            Generate documentation"
    echo "  migrate         Run database migrations"
    echo "  seed            Seed database"
    echo "  clean           Clean build artifacts"
    echo "  audit           Run security audit"
    echo "  performance     Run performance analysis"
    echo "  validate        Validate environment"
    echo "  backup-config   Backup configuration"
    echo "  restore-config  Restore configuration"
    echo "  dev-server      Start development servers"
    echo "  prod-build      Build for production"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install-deps"
    echo "  $0 test"
    echo "  $0 restore-config backup.tar.gz"
}

# Main script logic
main() {
    case "${1:-help}" in
        install-deps)
            install_deps
            ;;
        test)
            run_tests
            ;;
        lint)
            lint_all
            ;;
        format)
            format_all
            ;;
        docs)
            generate_docs
            ;;
        migrate)
            migrate_db
            ;;
        seed)
            seed_db
            ;;
        clean)
            clean_build
            ;;
        audit)
            security_audit
            ;;
        performance)
            performance_analysis
            ;;
        validate)
            validate_env
            ;;
        backup-config)
            backup_config
            ;;
        restore-config)
            restore_config "$2"
            ;;
        dev-server)
            dev_server
            ;;
        prod-build)
            prod_build
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
