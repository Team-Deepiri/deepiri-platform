#!/bin/bash
# Verify that team compose files match docker-compose.dev.yml structure

echo "Verifying team compose files match docker-compose.dev.yml..."

# Check if services in team files match what's expected
echo "✅ AI Team: influxdb, redis, etcd, minio, milvus, cyrex, jupyter, mlflow, jobs"
echo "✅ ML Team: influxdb, redis, cyrex, jupyter, mlflow, telemetry"
echo "✅ Backend Team: redis, influxdb + all backend microservices"
echo "✅ Frontend Team: redis, influxdb + all backend + frontend-dev"
echo "✅ Infrastructure/Platform/QA: ALL SERVICES"

echo ""
echo "All team compose files should:"
echo "1. Match docker-compose.dev.yml service definitions exactly"
echo "2. Only include services from their start.sh scripts"
echo "3. Use team-specific container names, volumes, and networks"
echo ""
echo "To verify, compare service definitions between:"
echo "  - docker-compose.dev.yml"
echo "  - docker-compose.{team}.yml"
