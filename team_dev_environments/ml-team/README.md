# ML Team Development Environment

## Overview

This directory contains build and start scripts for the ML Team's development environment.

## Services

**Primary Services:**
- ✅ **Cyrex AI Service** (Port 8000) - Model inference
- ✅ **Jupyter** (Port 8888) - Data analysis and model training
- ✅ **MLflow** (Port 5500) - Model versioning and tracking
- ✅ **Analytics Service** (Port 5004) - Feature engineering data

**Infrastructure:**
- ✅ **MongoDB** (Port 27017) - Training datasets
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
  mongodb influxdb redis \
  cyrex jupyter mlflow platform-analytics-service
```

### Rebuild After Code Changes

```bash
./build.sh
./start.sh
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

