# ML Team Development Environment

## Overview

This directory contains build and start scripts for the ML Team's development environment.

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
- ✅ **Cyrex AI Service** (Port 8000) - Model inference
- ✅ **Jupyter** (Port 8888) - Data analysis and model training
- ✅ **MLflow** (Port 5500) - Model versioning and tracking
- ✅ **Analytics Service** (Port 5004) - Feature engineering data

**Infrastructure:**
- ✅ **PostgreSQL** (Port 5432) - Training datasets metadata
- ✅ **InfluxDB** (Port 8086) - Time-series features, model metrics
- ✅ **Redis** (Port 6380) - Feature caching

## Usage

### Build Services

```bash
./build.sh
```

This builds:
- `cyrex`
- `jupyter`
- `platform-analytics-service`

### Start Services

```bash
./start.sh
```

This starts all required infrastructure and services.

### Stop Services

```bash
cd ../..
docker compose -f docker-compose.dev.yml stop \
  postgres influxdb redis \
  cyrex jupyter mlflow platform-analytics-service
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
docker compose -f docker-compose.ml-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.ml-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f jupyter
docker compose -f docker-compose.dev.yml logs -f platform-analytics-service
# ... etc for all services
```

## What You Work On

- `diri-cyrex/app/services/` - ML model implementations
- `diri-cyrex/train/` - Training pipelines
- `platform-services/backend/deepiri-platform-analytics-service/` - Analytics features

## Service URLs

- **MLflow**: http://localhost:5500
- **Jupyter**: http://localhost:8888
- **Cyrex**: http://localhost:8000
- **Analytics Service**: http://localhost:5004
- **PostgreSQL**: localhost:5432
- **pgAdmin**: http://localhost:5050 (email: admin@deepiri.com, password: admin)
- **Adminer**: http://localhost:8080 (System: PostgreSQL, Server: postgres, Username: deepiri, Password: deepiripassword, Database: deepiri)

## Database Setup

PostgreSQL is automatically initialized with the schema from `scripts/postgres-init.sql` on first startup. The database stores training datasets metadata.

