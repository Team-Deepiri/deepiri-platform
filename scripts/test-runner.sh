#!/bin/bash

# Trailblip MAG 2.0 - Comprehensive Test Runner
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
    
    # Install server test dependencies
    if [ -f "server/package.json" ]; then
        cd server
        npm install --silent
        cd ..
    fi
    
    # Install client test dependencies
    if [ -f "client/package.json" ]; then
        cd client
        npm install --silent
        cd ..
    fi
    
    # Install Python test dependencies
    if [ -f "python_backend/requirements.txt" ]; then
        cd python_backend
        pip install -r requirements.txt --quiet
        cd ..
    fi
    
    log_success "Test dependencies installed"
}

# Run server tests
test_server() {
    log_info "Testing Node.js server..."
    
    if [ -f "server/package.json" ]; then
        run_test "Server Unit Tests" "npm test" "server"
        
        # Run server integration tests if they exist
        if [ -f "server/tests/integration.test.js" ]; then
            run_test "Server Integration Tests" "npm run test:integration" "server"
        fi
        
        # Run server linting
        if npm run lint --silent 2>/dev/null; then
            log_success "Server linting passed"
        else
            log_warning "Server linting issues found"
        fi
    else
        log_warning "Server package.json not found, skipping server tests"
    fi
}

# Run Python backend tests
test_python_backend() {
    log_info "Testing Python backend..."
    
    if [ -f "python_backend/requirements.txt" ]; then
        run_test "Python Unit Tests" "python -m pytest tests/ -v" "python_backend"
        
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

# Run client tests
test_client() {
    log_info "Testing React client..."
    
    if [ -f "client/package.json" ]; then
        run_test "Client Unit Tests" "npm test -- --run" "client"
        
        # Run client linting
        if npm run lint --silent 2>/dev/null; then
            log_success "Client linting passed"
        else
            log_warning "Client linting issues found"
        fi
        
        # Run client build test
        if npm run build --silent 2>/dev/null; then
            log_success "Client build test passed"
        else
            log_error "Client build test failed"
        fi
    else
        log_warning "Client package.json not found, skipping client tests"
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
    if [ -f "server/package.json" ]; then
        cd server
        if npm audit --audit-level=moderate; then
            log_success "Server security audit passed"
        else
            log_warning "Server security vulnerabilities found"
        fi
        cd ..
    fi
    
    if [ -f "client/package.json" ]; then
        cd client
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
        echo "Trailblip MAG 2.0 - Test Report"
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
    log_info "Starting comprehensive test suite for Trailblip MAG 2.0"
    echo "=================================================="
    
    # Check dependencies
    check_dependencies
    
    # Install test dependencies
    install_test_deps
    
    # Run tests
    test_server
    test_python_backend
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
        test_python_backend
        ;;
    client)
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
        echo "Trailblip MAG 2.0 - Test Runner"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  server       Run server tests only"
        echo "  python       Run Python backend tests only"
        echo "  client       Run client tests only"
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
