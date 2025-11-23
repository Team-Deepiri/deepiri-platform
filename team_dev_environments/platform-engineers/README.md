# Platform Engineers Development Environment

## Overview

This directory contains build and start scripts for the Platform Engineers' development environment.

## Services

**Primary Services:**
- ✅ **API Gateway** - Platform routing and policies
- ✅ **All Microservices** - Platform standards and tooling
- ✅ **Infrastructure Services** - Platform infrastructure

**Infrastructure Needed:**
- ✅ **All services** - For platform tooling development
- ✅ **Kubernetes** - Platform orchestration
- ✅ **CI/CD pipelines** - Platform automation

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

- Platform standards and best practices
- Service mesh and observability
- CI/CD pipelines
- Developer tooling
- Service templates and scaffolding
- Cross-cutting concerns (logging, monitoring, tracing)

## Service URLs

- **API Gateway**: http://localhost:5000
- **Frontend**: http://localhost:5173
- **Cyrex**: http://localhost:8000
- **MLflow**: http://localhost:5500
- **Jupyter**: http://localhost:8888
- **Mongo Express**: http://localhost:8081

