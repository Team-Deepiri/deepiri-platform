# AI Team Development Environment

## Overview

This directory contains build and start scripts for the AI Team's development environment.

## Services

**Primary Services:**
- ✅ **Cyrex AI Service** (Port 8000) - Main AI/ML service
- ✅ **Jupyter** (Port 8888) - Experimentation and model development
- ✅ **MLflow** (Port 5500) - Experiment tracking and model registry
- ✅ **Challenge Service** (Port 5007) - Integration testing with AI

**Infrastructure:**
- ✅ **MongoDB** (Port 27017) - Training data, model metadata
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

