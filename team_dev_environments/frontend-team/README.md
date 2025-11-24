# Frontend Team Development Environment

## Overview

This directory contains build and start scripts for the Frontend Team's development environment.

## Services

**Primary Services:**
- ✅ **Frontend Service** (Port 5173) - React application
- ✅ **API Gateway** (Port 5000) - Backend API
- ✅ **Realtime Gateway** (Port 5008) - WebSocket for real-time features

**Infrastructure:**
- ✅ **MongoDB** (Port 27017) - Optional, for direct DB access in dev
- ✅ **Redis** (Port 6380) - Optional
- ✅ **InfluxDB** (Port 8086) - Optional
- ✅ **All Backend Services** - For API calls

## Usage

### Build Services

```bash
./build.sh
```

This builds:
- `frontend-dev`
- All backend microservices (api-gateway, auth-service, task-orchestrator, engagement-service, platform-analytics-service, notification-service, external-bridge-service, challenge-service, realtime-gateway)

### Start Services

```bash
./start.sh
```

This starts all infrastructure, backend services, and frontend.

### Stop Services

```bash
cd ../..
docker compose -f docker-compose.dev.yml stop \
  mongodb redis influxdb \
  api-gateway auth-service task-orchestrator \
  engagement-service platform-analytics-service \
  notification-service external-bridge-service \
  challenge-service realtime-gateway frontend-dev
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
docker compose -f docker-compose.frontend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.frontend-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f frontend-dev
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f auth-service
# ... etc for all services
```

## What You Work On

- `deepiri-web-frontend/` - React frontend
- API integration (`src/services/`)
- WebSocket integration (`src/services/multiplayerService.ts`)
- UI/UX components

## Service URLs

- **Frontend**: http://localhost:5173
- **API Gateway**: http://localhost:5000
- **Realtime Gateway**: http://localhost:5008

