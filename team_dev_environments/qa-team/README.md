# QA Team Development Environment

## Overview

This directory contains build and start scripts for the QA Team's development environment.

## Services

**Primary Services:**
- ✅ **All Services** - End-to-end testing
- ✅ **Frontend** - UI testing
- ✅ **API Gateway** - API testing
- ✅ **All Microservices** - Integration testing

**Infrastructure Needed:**
- ✅ **All databases** - Test data setup
- ✅ **All services** - Full stack testing

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

- End-to-end test suites
- Integration tests
- API testing
- Performance testing
- Load testing

## Service URLs

- **Frontend**: http://localhost:5173
- **API Gateway**: http://localhost:5000
- **Cyrex**: http://localhost:8000
- **MLflow**: http://localhost:5500
- **Jupyter**: http://localhost:8888
- **Mongo Express**: http://localhost:8081

