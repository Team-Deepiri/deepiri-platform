# Backend Team Development Environment

## Overview

This directory contains build and start scripts for the Backend Team's development environment.

## Services

**Primary Services:**
- ✅ **API Gateway** (Port 5000) - Entry point
- ✅ **Auth Service** (Port 5001) - Authentication
- ✅ **Task Orchestrator** (Port 5002) - Task management
- ✅ **Engagement Service** (Port 5003) - Gamification
- ✅ **Analytics Service** (Port 5004) - Analytics
- ✅ **Notification Service** (Port 5005) - Notifications
- ✅ **External Bridge Service** (Port 5006) - Integrations
- ✅ **Challenge Service** (Port 5007) - Challenges
- ✅ **Realtime Gateway** (Port 5008) - WebSocket

**Infrastructure:**
- ✅ **MongoDB** (Port 27017) - All services use MongoDB
- ✅ **Redis** (Port 6380) - Engagement and Notification services
- ✅ **InfluxDB** (Port 8086) - Auth and Analytics services

## Usage

### Build Services

```bash
./build.sh
```

This builds all backend microservices:
- `api-gateway`
- `auth-service`
- `task-orchestrator`
- `engagement-service`
- `platform-analytics-service`
- `notification-service`
- `external-bridge-service`
- `challenge-service`
- `realtime-gateway`

### Start Services

```bash
./start.sh
```

This starts all infrastructure and backend services.

### Stop Services

```bash
cd ../..
docker compose -f docker-compose.dev.yml stop \
  mongodb redis influxdb \
  api-gateway auth-service task-orchestrator \
  engagement-service platform-analytics-service \
  notification-service external-bridge-service \
  challenge-service realtime-gateway
```

### Rebuild After Code Changes

```bash
./build.sh
./start.sh
```

## What You Work On

- `platform-services/backend/*/` - All microservices
- `deepiri-core-api/` - Legacy monolith (being migrated)
- API Gateway routing logic
- Service-to-service communication

## Service URLs

- **API Gateway**: http://localhost:5000
- **Auth Service**: http://localhost:5001
- **Task Orchestrator**: http://localhost:5002
- **Engagement Service**: http://localhost:5003
- **Analytics Service**: http://localhost:5004
- **Notification Service**: http://localhost:5005
- **External Bridge**: http://localhost:5006
- **Challenge Service**: http://localhost:5007
- **Realtime Gateway**: http://localhost:5008

