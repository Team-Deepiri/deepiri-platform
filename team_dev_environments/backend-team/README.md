# Backend Team Development Environment

## Overview

This directory contains build and start scripts for the Backend Team's development environment.

## ⚠️ Initial Setup (One-Time)

**Before using this environment, set up Git hooks from the repository root:**

```bash
# From repository root
cd ../..
./setup-hooks.sh
```

This protects the `main` and `dev` branches from accidental pushes. See [BRANCH_PROTECTION.md](../../BRANCH_PROTECTION.md) for details.

## Services

**Primary Services:**
- ✅ **API Gateway** (Port 5100) - Entry point (uses 5100 to avoid macOS AirPlay conflict on 5000)
- ✅ **Auth Service** (Port 5001) - Authentication
- ✅ **Task Orchestrator** (Port 5002) - Task management
- ✅ **Engagement Service** (Port 5003) - Gamification
- ✅ **Analytics Service** (Port 5004) - Analytics
- ✅ **Notification Service** (Port 5005) - Notifications
- ✅ **External Bridge Service** (Port 5006) - Integrations
- ✅ **Challenge Service** (Port 5007) - Challenges
- ✅ **Realtime Gateway** (Port 5008) - WebSocket

**Infrastructure:**
- ✅ **PostgreSQL** (Port 5432) - All services use PostgreSQL
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
  postgres redis influxdb \
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
docker compose -f docker-compose.backend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.backend-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f auth-service
docker compose -f docker-compose.dev.yml logs -f task-orchestrator
# ... etc for all services
```

## What You Work On

- `platform-services/backend/*/` - All microservices
- `deepiri-core-api/` - Legacy monolith (being migrated)
- API Gateway routing logic
- Service-to-service communication

## Service URLs

- **API Gateway**: http://localhost:5100 (or set `API_GATEWAY_PORT` environment variable to customize)
- **Auth Service**: http://localhost:5001
- **Task Orchestrator**: http://localhost:5002
- **Engagement Service**: http://localhost:5003
- **Analytics Service**: http://localhost:5004
- **Notification Service**: http://localhost:5005
- **External Bridge**: http://localhost:5006
- **Challenge Service**: http://localhost:5007
- **Realtime Gateway**: http://localhost:5008
- **PostgreSQL**: localhost:5432
- **pgAdmin**: http://localhost:5050 (email: admin@deepiri.com, password: admin)
- **Adminer**: http://localhost:8080 (System: PostgreSQL, Server: postgres, Username: deepiri, Password: deepiripassword, Database: deepiri)

## Database Setup

PostgreSQL is automatically initialized with the schema from `scripts/postgres-init.sql` on first startup. The database includes:
- `public` schema - Main application data (users, tasks, quests, rewards, etc.)
- `analytics` schema - Analytics and metrics (momentum, streaks, boosts, etc.)
- `audit` schema - Audit logs and history

For services using Prisma (e.g., engagement-service), migrations are handled automatically during service startup. The Prisma client is generated during the Docker build process.

