# AI Team Development Environment

## Overview

This directory contains build and start scripts for the AI Team's development environment.

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
- ✅ **Cyrex AI Service** (Port 8000) - Main AI/ML service
- ✅ **Jupyter** (Port 8888) - Experimentation and model development
- ✅ **MLflow** (Port 5500) - Experiment tracking and model registry
- ✅ **Challenge Service** (Port 5007) - Integration testing with AI

**Infrastructure:**
- ✅ **PostgreSQL** (Port 5432) - Training data, model metadata
- ✅ **InfluxDB** (Port 8086) - Model performance metrics, training metrics
- ✅ **Redis** (Port 6380) - Caching model predictions
- ✅ **Milvus** (Port 19530) - Vector database for RAG
- ✅ **etcd** - Milvus metadata
- ✅ **MinIO** - Milvus object storage

## Usage

### Build Services

```bash
./build.sh
```

This builds:
- `cyrex`
- `jupyter`
- `challenge-service`

### Start Services

```bash
./start.sh
```

This starts all required infrastructure and services.

### Stop Services

```bash
cd ../..
docker compose -f docker-compose.dev.yml stop \
  mongodb influxdb redis etcd minio milvus \
  cyrex jupyter mlflow challenge-service
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
docker compose -f docker-compose.ai-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.ai-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f jupyter
docker compose -f docker-compose.dev.yml logs -f challenge-service
# ... etc for all services
```

## What You Work On

- `diri-cyrex/` - Python AI service
  - Challenge generation algorithms
  - Task understanding models
  - RL models for personalization
  - Multimodal AI integration
- `platform-services/backend/deepiri-challenge-service/` - Challenge service integration

## Service URLs

- **MLflow**: http://localhost:5500
- **Jupyter**: http://localhost:8888
- **Cyrex**: http://localhost:8000
- **Challenge Service**: http://localhost:5007

