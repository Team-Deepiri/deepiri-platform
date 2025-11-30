#!/bin/bash

# tripblip MAG 2.0 - Comprehensive Test Runner
# Runs all tests across the entire application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

# Test runner function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local test_dir="$3"
    
    log_info "Running $test_name..."
    
    if [ -n "$test_dir" ]; then
        cd "$test_dir"
    fi
    
    if eval "$test_command"; then
        log_success "$test_name passed"
        ((PASSED_TESTS++))
    else
        log_error "$test_name failed"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
    
    if [ -n "$test_dir" ]; then
        cd - > /dev/null
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        exit 1
    fi
    
    # Check Python
    if ! command -v python &> /dev/null; then
        log_error "Python is not installed"
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed"
        exit 1
    fi
    
    # Check pip
    if ! command -v pip &> /dev/null; then
        log_error "pip is not installed"
        exit 1
    fi
    
    log_success "All dependencies are available"
}

# Install test dependencies
install_test_deps() {
    log_info "Installing test dependencies..."
    
    # Install API server test dependencies
    if [ -f "deepiri-core-api/package.json" ]; then
        cd deepiri-core-api
        npm install --silent
        cd ..
    fi
    
    # Install deepiri-web-frontend test dependencies
    if [ -f "deepiri-web-frontend/package.json" ]; then
        cd deepiri-web-frontend
        npm install --silent
        cd ..
    fi
    
    # Install Python test dependencies
    if [ -f "diri-cyrex/requirements.txt" ]; then
        cd diri-cyrex
        pip install -r requirements.txt --quiet
        cd ..
    fi
    
    log_success "Test dependencies installed"
}

# Run API server tests
test_server() {
    log_info "Testing Node.js API server..."
    
    if [ -f "deepiri-core-api/package.json" ]; then
        run_test "API Server Unit Tests" "npm test" "deepiri-core-api"
        
        # Run API server integration tests if they exist
        if [ -f "deepiri-core-api/tests/integration.test.js" ]; then
            run_test "API Server Integration Tests" "npm run test:integration" "deepiri-core-api"
        fi
        
        # Run API server linting
        if npm run lint --silent 2>/dev/null; then
            log_success "API server linting passed"
        else
            log_warning "API server linting issues found"
        fi
    else
        log_warning "API server package.json not found, skipping API server tests"
    fi
}

# Run Python backend tests
test_diri-cyrex() {
    log_info "Testing Python backend..."
    
    if [ -f "diri-cyrex/requirements.txt" ]; then
        run_test "Python Unit Tests" "python -m pytest tests/ -v" "diri-cyrex"
        
        # Run Python linting
        if command -v flake8 &> /dev/null; then
            if flake8 app/ --max-line-length=100 --ignore=E203,W503; then
                log_success "Python linting passed"
            else
                log_warning "Python linting issues found"
            fi
        fi
        
        # Run Python type checking
        if command -v mypy &> /dev/null; then
            if mypy app/ --ignore-missing-imports; then
                log_success "Python type checking passed"
            else
                log_warning "Python type checking issues found"
            fi
        fi
    else
        log_warning "Python requirements.txt not found, skipping Python tests"
    fi
}

# Run deepiri-web-frontend tests
test_client() {
    log_info "Testing React deepiri-web-frontend..."
    
    if [ -f "deepiri-web-frontend/package.json" ]; then
        run_test "Frontend Unit Tests" "npm test -- --run" "deepiri-web-frontend"
        
        # Run deepiri-web-frontend linting
        if npm run lint --silent 2>/dev/null; then
            log_success "Frontend linting passed"
        else
            log_warning "Frontend linting issues found"
        fi
        
        # Run deepiri-web-frontend build test
        if npm run build --silent 2>/dev/null; then
            log_success "Frontend build test passed"
        else
            log_error "Frontend build test failed"
        fi
    else
        log_warning "Frontend package.json not found, skipping deepiri-web-frontend tests"
    fi
}

# Run integration tests
test_integration() {
    log_info "Running integration tests..."
    
    # Check if Docker is available for integration tests
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        log_info "Running Docker-based integration tests..."
        
        # Start services for integration testing
        if docker-compose up -d --build; then
            log_info "Services started for integration testing"
            
            # Wait for services to be ready
            sleep 30
            
            # Run health checks
            if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
                log_success "Backend health check passed"
            else
                log_error "Backend health check failed"
            fi
            
            if curl -f http://localhost:8000/health > /dev/null 2>&1; then
                log_success "Python agent health check passed"
            else
                log_error "Python agent health check failed"
            fi
            
            # Stop services
            docker-compose down
        else
            log_error "Failed to start services for integration testing"
        fi
    else
        log_warning "Docker not available, skipping integration tests"
    fi
}

# Run security tests
test_security() {
    log_info "Running security tests..."
    
    # Run npm audit for Node.js projects
    if [ -f "deepiri-core-api/package.json" ]; then
        cd deepiri-core-api
        if npm audit --audit-level=moderate; then
            log_success "Server security audit passed"
        else
            log_warning "Server security vulnerabilities found"
        fi
        cd ..
    fi
    
    if [ -f "deepiri-web-frontend/package.json" ]; then
        cd deepiri-web-frontend
        if npm audit --audit-level=moderate; then
            log_success "Client security audit passed"
        else
            log_warning "Client security vulnerabilities found"
        fi
        cd ..
    fi
    
    # Run Python security audit
    if command -v safety &> /dev/null; then
        if safety check; then
            log_success "Python security audit passed"
        else
            log_warning "Python security vulnerabilities found"
        fi
    fi
}

# Run performance tests
test_performance() {
    log_info "Running performance tests..."
    
    # Check if services are running
    if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
        log_info "Running API performance tests..."
        
        # Simple load test with curl
        local start_time=$(date +%s)
        for i in {1..10}; do
            curl -f http://localhost:5000/api/health > /dev/null 2>&1
        done
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $duration -lt 10 ]; then
            log_success "API performance test passed (${duration}s for 10 requests)"
        else
            log_warning "API performance test slow (${duration}s for 10 requests)"
        fi
    else
        log_warning "Services not running, skipping performance tests"
    fi
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    local report_file="test-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "tripblip MAG 2.0 - Test Report"
        echo "Generated: $(date)"
        echo "=================================="
        echo ""
        echo "Total Tests: $TOTAL_TESTS"
        echo "Passed: $PASSED_TESTS"
        echo "Failed: $FAILED_TESTS"
        echo "Success Rate: $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%"
        echo ""
        
        if [ $FAILED_TESTS -eq 0 ]; then
            echo "Status: ALL TESTS PASSED ✅"
        else
            echo "Status: SOME TESTS FAILED ❌"
        fi
    } > "$report_file"
    
    log_success "Test report generated: $report_file"
}

# Main test runner
main() {
    log_info "Starting comprehensive test suite for tripblip MAG 2.0"
    echo "=================================================="
    
    # Check dependencies
    check_dependencies
    
    # Install test dependencies
    install_test_deps
    
    # Run tests
    test_server
    test_diri-cyrex
    test_client
    test_integration
    test_security
    test_performance
    
    # Generate report
    generate_report
    
    # Summary
    echo ""
    echo "=================================================="
    log_info "Test Summary:"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed! Please review the output above."
        exit 1
    fi
}

# Handle command line arguments
case "${1:-all}" in
    server)
        check_dependencies
        install_test_deps
        test_server
        ;;
    python)
        check_dependencies
        install_test_deps
        test_diri-cyrex
        ;;
    deepiri-web-frontend)
        check_dependencies
        install_test_deps
        test_client
        ;;
    integration)
        test_integration
        ;;
    security)
        test_security
        ;;
    performance)
        test_performance
        ;;
    all)
        main
        ;;
    help|--help|-h)
        echo "Deepiri - Test Runner"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  server       Run API server tests only"
        echo "  python       Run Python backend tests only"
        echo "  deepiri-web-frontend     Run deepiri-web-frontend tests only"
        echo "  integration  Run integration tests only"
        echo "  security     Run security tests only"
        echo "  performance  Run performance tests only"
        echo "  all          Run all tests (default)"
        echo "  help         Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
