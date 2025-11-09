#!/bin/bash
# Run all AI tests and benchmarks

echo "Running AI Test Suite"
echo "======================"

# Run unit tests
echo "Running unit tests..."
pytest tests/ai/ -v --tb=short

# Run integration tests
echo "Running integration tests..."
pytest tests/integration/ -v --tb=short

# Run benchmarks
echo "Running benchmarks..."
pytest tests/ai/benchmarks/ -v --benchmark-only

# Run with coverage
echo "Generating coverage report..."
pytest tests/ --cov=app --cov-report=html --cov-report=term

echo "Test suite complete!"

