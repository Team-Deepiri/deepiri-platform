# Infrastructure Team Development Environment

## Overview

This directory contains build and start scripts for the Infrastructure Team's development environment.

## Services

**Primary Services:**
- ✅ **All Infrastructure Services**
  - MongoDB (Port 27017)
  - Redis (Port 6379)
  - InfluxDB (Port 8086)
  - Mongo Express (Port 8081) - DB admin UI
- ✅ **API Gateway** (Port 5000) - Routing and load balancing
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

## What You Work On

- `ops/k8s/` - Kubernetes manifests
- `docker-compose.*.yml` - Service orchestration
- `skaffold/*.yaml` - Build and deployment configs
- Infrastructure monitoring and scaling

## Service URLs

- **MongoDB**: localhost:27017
- **Mongo Express**: http://localhost:8081
- **Redis**: localhost:6380
- **InfluxDB**: http://localhost:8086
- **API Gateway**: http://localhost:5000

