# Commands Reference - Quick Cheat Sheet

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

## 🚀 Starting Services

### ⚡ FASTEST: Docker Compose (Pre-built Containers)
```bash
./scripts/start-docker-dev.sh        # Linux/WSL
.\scripts\start-docker-dev.ps1       # Windows

# Or directly
docker compose -f docker-compose.dev.yml up -d
```

### 🔄 HYBRID: Build with Skaffold, Run with Docker Compose
```bash
./scripts/build-with-skaffold-run-with-docker.sh        # Linux/WSL
.\scripts\build-with-skaffold-run-with-docker.ps1       # Windows
```

**Manual steps:**
```bash
# 1. Ensure Minikube is running
minikube status
# If not: minikube start --driver=docker --cpus=4 --memory=8192

# 2. Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

# 3. Build with Skaffold
skaffold build -f skaffold-local.yaml

# 4. Run with Docker Compose (keep using Minikube's Docker daemon)
docker compose -f docker-compose.dev.yml up -d
```

### 🔄 WITH FILE SYNC: Skaffold (Active Development)
```bash
./scripts/start-skaffold-dev.sh        # Linux/WSL
.\scripts\start-skaffold-dev.ps1       # Windows

# Or directly
skaffold dev -f skaffold-local.yaml --port-forward
```

## 🛑 Stopping Services

### Docker Compose
```bash
docker compose -f docker-compose.dev.yml down
```

### Skaffold
```bash
skaffold delete -f skaffold-local.yaml
# Or: Press Ctrl+C in Skaffold terminal
```

## 📋 Viewing Logs

### Docker Compose
```bash
# All services
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f backend
docker compose -f docker-compose.dev.yml logs -f cyrex
```

### Skaffold/Kubernetes
```bash
# Backend
kubectl logs -f deployment/deepiri-core-api

# Cyrex
kubectl logs -f deployment/deepiri-cyrex

# All pods
kubectl get pods
kubectl logs -f <pod-name>
```

## 🔨 Building

### Full Rebuild
```bash
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows
```

### Build with Skaffold
```bash
# Ensure Minikube Docker daemon is active
eval $(minikube docker-env)

# Build
skaffold build -f skaffold-local.yaml
```

### Build with Docker Compose
```bash
docker compose -f docker-compose.dev.yml build
```

## 🔧 Prerequisites Setup

### Install kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Start Minikube
```bash
minikube start --driver=docker --cpus=4 --memory=8192
minikube status
```

### Configure Docker for Minikube
```bash
eval $(minikube docker-env)
docker ps  # Verify it works
```

## 📊 Quick Comparison

| Task | Fastest Method | Command |
|------|---------------|---------|
| **Run pre-built** | Docker Compose | `docker compose -f docker-compose.dev.yml up -d` |
| **Build + Run** | Hybrid | `./scripts/build-with-skaffold-run-with-docker.sh` |
| **Active coding** | Skaffold | `skaffold dev -f skaffold-local.yaml --port-forward` |
| **View logs** | Docker Compose | `docker compose -f docker-compose.dev.yml logs -f` |
| **Stop** | Docker Compose | `docker compose -f docker-compose.dev.yml down` |

## 📚 Full Documentation

- **[HYBRID_WORKFLOW.md](HYBRID_WORKFLOW.md)** - Detailed hybrid workflow guide
- **[SPEED_COMPARISON.md](SPEED_COMPARISON.md)** - Speed comparison
- **[QUICK_START.md](QUICK_START.md)** - Quick start guide

