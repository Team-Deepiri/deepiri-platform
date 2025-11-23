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

## What You Work On

- `deepiri-web-frontend/` - React frontend
- API integration (`src/services/`)
- WebSocket integration (`src/services/multiplayerService.ts`)
- UI/UX components

## Service URLs

- **Frontend**: http://localhost:5173
- **API Gateway**: http://localhost:5000
- **Realtime Gateway**: http://localhost:5008

