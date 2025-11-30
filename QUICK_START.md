# ⚡ Quick Start Guide - Complete Commands Reference

## 🎯 Quick Reference

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

# Or use build script
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell
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
docker compose -f docker-compose.<team_name>-team.yml up -d
# Examples:
docker compose -f docker-compose.ai-team.yml up -d
docker compose -f docker-compose.backend-team.yml up -d
docker compose -f docker-compose.frontend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.<team_name>-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f auth-service
# ... etc for all services
```

---

## 🎯 TL;DR: What's Fastest?

**After builds are done:**
1. **🥇 Docker Compose** - ~5-10 seconds (FASTEST)
2. **🥈 Direct Docker** - ~5-10 seconds (manual)
3. **🥉 Skaffold** - ~30-60 seconds (has file sync)

---

## 🔨 How to Build

### Option 1: Build with Skaffold (Recommended for K8s)

```bash
# Setup Minikube (first time only)
eval $(minikube docker-env)
minikube start --driver=docker --cpus=4 --memory=8192

# Build all images with Skaffold
skaffold build -f skaffold-local.yaml -p dev-compose

# Images are automatically tagged with :latest for Docker Compose
```

### Option 2: Build with Docker Compose

```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Build specific service
docker compose -f docker-compose.dev.yml build api-gateway

# Build without cache (fresh build)
docker compose -f docker-compose.dev.yml build --no-cache
```

### Option 3: Full Rebuild Script

```bash
# Clean rebuild (removes old images, rebuilds fresh)
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows
```

---

## 🚀 How to Run

### ⚡ FASTEST: Docker Compose (Pre-built Containers)

```bash
# Start all services (uses existing images)
./scripts/start-docker-dev.sh        # Linux/WSL
.\scripts\start-docker-dev.ps1       # Windows

# Or directly
docker compose -f docker-compose.dev.yml up -d

# Start specific service
docker compose -f docker-compose.dev.yml up -d api-gateway

# Start multiple services
docker compose -f docker-compose.dev.yml up -d mongodb redis api-gateway
```

**Speed:** ~5-10 seconds  
**Best for:** Daily dev, quick restarts

### 🔄 WITH FILE SYNC: Skaffold (Active Development)

```bash
# Start with file sync (watches for code changes)
./scripts/start-skaffold-dev.sh        # Linux/WSL
.\scripts\start-skaffold-dev.ps1       # Windows

# Or directly
skaffold dev -f skaffold-local.yaml --port-forward
```

**Speed:** ~30-60 seconds  
**Best for:** Active coding with instant file sync

### 🔄 Hybrid: Build with Skaffold, Run with Docker Compose

```bash
# Build with Skaffold (uses Minikube Docker)
eval $(minikube docker-env)
skaffold build -f skaffold-local.yaml -p dev-compose

# Run with Docker Compose (fastest!)
docker compose -f docker-compose.dev.yml up -d
```

---

## 🛑 How to Stop

### Docker Compose

```bash
# Stop all services (keeps containers)
docker compose -f docker-compose.dev.yml stop

# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Stop and remove containers + volumes (WARNING: Deletes data!)
docker compose -f docker-compose.dev.yml down -v

# Stop specific service
docker compose -f docker-compose.dev.yml stop api-gateway
docker compose -f docker-compose.dev.yml rm -f api-gateway
```

### Skaffold

```bash
# Stop Skaffold (press Ctrl+C in Skaffold terminal - auto-cleanup)
# Or manually:
skaffold delete -f skaffold-local.yaml

# Or use script
./scripts/stop-skaffold.sh        # Linux/Mac
.\scripts\stop-skaffold.ps1       # Windows
```

---

## 📋 How to Check Logs

### View All Services Logs

```bash
# All services (follow mode)
docker compose -f docker-compose.dev.yml logs -f

# All services (last 100 lines)
docker compose -f docker-compose.dev.yml logs --tail=100

# All services (since last 10 minutes)
docker compose -f docker-compose.dev.yml logs --since 10m
```

### View Individual Service Logs

```bash
# API Gateway
docker compose -f docker-compose.dev.yml logs -f api-gateway

# Auth Service
docker compose -f docker-compose.dev.yml logs -f auth-service

# Task Orchestrator
docker compose -f docker-compose.dev.yml logs -f task-orchestrator

# Engagement Service
docker compose -f docker-compose.dev.yml logs -f engagement-service

# Analytics Service
docker compose -f docker-compose.dev.yml logs -f platform-analytics-service

# Notification Service
docker compose -f docker-compose.dev.yml logs -f notification-service

# External Bridge Service
docker compose -f docker-compose.dev.yml logs -f external-bridge-service

# Challenge Service
docker compose -f docker-compose.dev.yml logs -f challenge-service

# Realtime Gateway
docker compose -f docker-compose.dev.yml logs -f realtime-gateway

# Cyrex AI Service
docker compose -f docker-compose.dev.yml logs -f cyrex

# Frontend
docker compose -f docker-compose.dev.yml logs -f frontend

# Infrastructure Services
docker compose -f docker-compose.dev.yml logs -f mongodb
docker compose -f docker-compose.dev.yml logs -f redis
docker compose -f docker-compose.dev.yml logs -f influxdb
```

### View Multiple Services Logs

```bash
# Multiple services at once
docker compose -f docker-compose.dev.yml logs -f api-gateway auth-service cyrex

# All backend services
docker compose -f docker-compose.dev.yml logs -f api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway
```

### Skaffold Logs (Kubernetes)

```bash
# All pods
kubectl logs -f -l app=deepiri

# Specific deployment
kubectl logs -f deployment/api-gateway
kubectl logs -f deployment/cyrex
kubectl logs -f deployment/auth-service

# All pods in namespace
kubectl logs -f --all-namespaces
```

---

## 📊 Check Service Status

```bash
# List all running containers
docker compose -f docker-compose.dev.yml ps

# Check specific service
docker compose -f docker-compose.dev.yml ps api-gateway

# Check resource usage
docker stats

# Check service health
curl http://localhost:5000/health  # API Gateway
curl http://localhost:5001/health  # Auth Service
curl http://localhost:8000/health   # Cyrex AI
```

---

## 📊 When to Use What

| Scenario | Use | Command |
|----------|-----|---------|
| **Quick test** | Docker Compose | `docker compose -f docker-compose.dev.yml up -d` |
| **Daily development** | Docker Compose | `./scripts/start-docker-dev.sh` |
| **Active coding** | Skaffold | `skaffold dev -f skaffold-local.yaml --port-forward` |
| **Kubernetes testing** | Skaffold | `skaffold run -f skaffold-local.yaml` |
| **Single service** | Direct Docker | `docker run -d -p 5000:5000 deepiri-core-api:latest` |

---

## 🔄 Restart Services

```bash
# Restart all services
docker compose -f docker-compose.dev.yml restart

# Restart specific service
docker compose -f docker-compose.dev.yml restart api-gateway

# Rebuild and restart
docker compose -f docker-compose.dev.yml up -d --build api-gateway
```

---

## 📝 Full Documentation

- **[SPEED_COMPARISON.md](SPEED_COMPARISON.md)** - Detailed speed comparison
- **[README.md](README.md)** - Complete project overview
- **[START_EVERYTHING.md](START_EVERYTHING.md)** - Detailed startup guide
- **[SERVICE_COMMUNICATION_AND_TEAMS.md](SERVICE_COMMUNICATION_AND_TEAMS.md)** - Service architecture and team requirements

