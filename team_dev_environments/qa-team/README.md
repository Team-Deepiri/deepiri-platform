# QA Team Development Environment

## Overview

This directory contains build and start scripts for the QA Team's development environment.

## Services

**Primary Services:**
- ✅ **All Services** - End-to-end testing
- ✅ **Frontend** - UI testing
- ✅ **API Gateway** - API testing
- ✅ **All Microservices** - Integration testing

**Infrastructure Needed:**
- ✅ **All databases** - Test data setup
- ✅ **All services** - Full stack testing

## Usage

### Build Services

```bash
./build.sh
```

This builds all services.

### Start Services

```bash
./start.sh
```

This starts everything.

### Stop Services

```bash
cd ../..
docker compose -f docker-compose.dev.yml down
```

### Rebuild After Code Changes

```bash
./build.sh
./start.sh
```

## Quick Reference

### Setup Minikube (for Kubernetes/Skaffold builds)
```bash
# Check if Minikube is running
minikube status

# If not running, start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### Build
```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Or use your team's build script
./build.sh
```

### When you DO need to build / rebuild
Only build if:
1. **Dockerfile changes**
2. **package.json/requirements.txt changes** (dependencies)
3. **First time setup**

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!

### Run all services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop all services
```bash
docker compose -f docker-compose.dev.yml down
```

### Running only services you need for your team
```bash
docker compose -f docker-compose.qa-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.qa-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f frontend-dev
# ... etc for all services
```

## What You Work On

- End-to-end test suites
- Integration tests
- API testing
- Performance testing
- Load testing

## Service URLs

- **Frontend**: http://localhost:5173
- **API Gateway**: http://localhost:5000
- **Cyrex**: http://localhost:8000
- **MLflow**: http://localhost:5500
- **Jupyter**: http://localhost:8888
- **Mongo Express**: http://localhost:8081

