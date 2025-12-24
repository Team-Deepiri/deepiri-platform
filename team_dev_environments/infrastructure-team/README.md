# Infrastructure Team Development Environment

## Overview

This directory contains build and start scripts for the Infrastructure Team's development environment.

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
- ✅ **All Infrastructure Services**
  - PostgreSQL (Port 5432) - Primary database
  - pgAdmin (Port 5050) - PostgreSQL admin UI
  - Adminer (Port 8080) - Lightweight DB admin UI
  - Redis (Port 6379) - Caching and sessions
  - InfluxDB (Port 8086) - Time-series data
- ✅ **API Gateway** (Port 5100) - Routing and load balancing
- ✅ **All Microservices** - For monitoring and scaling

**Infrastructure Needed:**
- ✅ **All databases** - Setup, backup, monitoring
- ✅ **Kubernetes/Minikube** - Orchestration
- ✅ **Monitoring tools** - Prometheus, Grafana (future)

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
docker compose -f docker-compose.infrastructure-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.infrastructure-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f postgres
docker compose -f docker-compose.dev.yml logs -f redis
# ... etc for all services
```

## What You Work On

- `ops/k8s/` - Kubernetes manifests
- `docker-compose.*.yml` - Service orchestration
- `skaffold/*.yaml` - Build and deployment configs
- Infrastructure monitoring and scaling

## Service URLs

- **PostgreSQL**: localhost:5432
- **pgAdmin**: http://localhost:5050 (email: admin@deepiri.com, password: admin)
- **Adminer**: http://localhost:8080 (System: PostgreSQL, Server: postgres, Username: deepiri, Password: deepiripassword, Database: deepiri)
- **Redis**: localhost:6380
- **InfluxDB**: http://localhost:8086
- **API Gateway**: http://localhost:5100 (or set `API_GATEWAY_PORT` environment variable to customize)

## Database Setup

PostgreSQL is automatically initialized with the schema from `scripts/postgres-init.sql` on first startup. The database includes:
- `public` schema - Main application data
- `analytics` schema - Analytics and metrics
- `audit` schema - Audit logs and history

For services using Prisma, migrations are handled automatically during service startup.

