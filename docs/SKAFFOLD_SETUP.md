# Skaffold Setup Guide for Deepiri

This guide explains how to use Skaffold with Minikube for local Kubernetes development on WSL2.

## Overview

Skaffold provides:
- **Smart rebuilds** - Only rebuilds when files actually change
- **File sync** - Instant updates without full rebuilds
- **Auto port-forwarding** - Automatic port forwarding for services
- **Log streaming** - Real-time logs from all services
- **Cleanup on exit** - Automatic cleanup when you stop
- **No duplicate images** - Proper dependency graph handling

## Prerequisites

1. **WSL2** with Ubuntu or similar Linux distribution
2. **Docker Engine** running in WSL2 (recommended - more reliable than Docker Desktop)
   - **Quick Install:** Run `./scripts/setup-docker-wsl2.sh` (see [QUICK-START-SCRIPTS.md](../QUICK-START-SCRIPTS.md))
   - The script installs Docker Engine with GPG key verification
   - After installation, restart WSL2: `wsl --shutdown` (in Windows PowerShell as Admin)
3. **Minikube** installed
4. **kubectl** installed
5. **Skaffold** installed

**Why Docker Engine instead of Docker Desktop?**
- More reliable WSL2 integration (no socket connection issues)
- Better performance in WSL2
- Full control over Docker daemon
- No need for Docker Desktop GUI

## Installation

### Install Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### Install kubectl

```bash
# Download and install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

**Note:** If you get "kubectl: executable file not found in $PATH" errors, make sure kubectl is installed and in your PATH. You can verify with `which kubectl` (should show `/usr/local/bin/kubectl`).

### Install Skaffold

```bash
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold
sudo mv skaffold /usr/local/bin/
```

Or use package managers:
- **Linux**: `curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && sudo install skaffold /usr/local/bin/`
- **Windows (Chocolatey)**: `choco install skaffold`
- **macOS (Homebrew)**: `brew install skaffold`

## Quick Start

### 1. Setup Minikube

Run the setup script:

```bash
# Linux/WSL2
./scripts/setup-minikube-wsl2.sh

# Windows PowerShell
.\scripts\setup-minikube-wsl2.ps1
```

Or manually:

```bash
# Start Minikube with Docker driver
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### 2. Start Development Environment

**Using helper script (recommended):**
```bash
# Linux/WSL2
./scripts/start-skaffold-dev.sh

# Windows PowerShell
.\scripts\start-skaffold-dev.ps1
```

The script automatically:
- ✅ Uses `skaffold-local.yaml` config file
- ✅ Configures kubectl for Minikube
- ✅ Unsets in-cluster config variables (prevents connection errors)
- ✅ Sets up proper KUBECONFIG

**Or manually:**
```bash
# Make sure you're using Minikube's Docker daemon
eval $(minikube docker-env)

# Run Skaffold (use skaffold-local.yaml for local dev)
skaffold dev -f skaffold-local.yaml --port-forward
```

## How It Works

### Build Process

1. **Initial Build**: Skaffold builds all Docker images using Minikube's Docker daemon
2. **Smart Rebuilds**: Only rebuilds when source files change
3. **File Sync**: For supported file types (`.ts`, `.js`, `.py`), files are synced directly to running containers without rebuilds

### Deployment

1. **Kubernetes Manifests**: All manifests in `ops/k8s/` are deployed
2. **Ordering**: Infrastructure services (MongoDB, Redis) are deployed first
3. **Application Services**: Backend and Cyrex are deployed after infrastructure

### Port Forwarding

Skaffold automatically forwards:
- Backend API: `localhost:5000`
- Cyrex AI Service: `localhost:8000`
- MongoDB: `localhost:27017`
- Redis: `localhost:6379`
- LocalAI: `localhost:8080`

## Configuration

### Skaffold Configuration Files

This project includes two Skaffold configuration files:

- **`skaffold-local.yaml`** - For local development with Minikube
  - Uses kubeconfig (not in-cluster config)
  - Prevents Kubernetes connection errors
  - Local builds (no push to registry)
  - File sync enabled

- **`skaffold-cloud.yaml`** - For cloud/production deployments
  - Supports both kubeconfig (CI/CD) and in-cluster config
  - Pushes images to container registry
  - Production-optimized builds

**See [SKAFFOLD_CONFIGS.md](../SKAFFOLD_CONFIGS.md) for complete documentation on both config files.**

### Skaffold Local Configuration (`skaffold-local.yaml`)

The local development configuration file defines:

- **Build artifacts**: Docker images to build (backend, cyrex)
- **Sync rules**: Files that can be synced without rebuilds
- **Deploy manifests**: Kubernetes manifests to deploy
- **Port forwarding**: Automatic port forwarding rules
- **Profiles**: Different configurations for dev/prod

### File Sync

Files are automatically synced to running containers:

**Backend**:
- `**/*.ts` → `/app/src/`
- `**/*.js` → `/app/dist/`
- `**/*.json` → `/app/`

**Cyrex**:
- `**/*.py` → `/app/`
- `**/*.txt` → `/app/`
- `**/*.yml` → `/app/`

### Profiles

#### Development Profile (`dev`)

```bash
skaffold dev --profile=dev --port-forward
```

Features:
- Local builds (no push to registry)
- Aggressive file sync
- Force deployment updates

#### Production Profile (`prod`)

```bash
skaffold run --profile=prod
```

Features:
- Pushes to container registry
- Uses Google Cloud Build (configure your project ID)
- Production-optimized builds

## Common Workflows

### Start Everything

```bash
# Setup and start
./scripts/setup-minikube-wsl2.sh
./scripts/start-skaffold-dev.sh  # Uses skaffold-local.yaml automatically
```

### Rebuild Specific Service

```bash
# Rebuild only backend
skaffold build --artifact=deepiri-core-api

# Rebuild only cyrex
skaffold build --artifact=deepiri-cyrex
```

### View Logs

```bash
# All services (via Skaffold)
skaffold dev --port-forward

# Specific service
kubectl logs -f deployment/deepiri-core-api
kubectl logs -f deployment/deepiri-cyrex
```

### Access Services

```bash
# Backend API
curl http://localhost:5000/api/health

# Cyrex AI Service
curl http://localhost:8000/health

# MongoDB (via port-forward)
mongosh mongodb://localhost:27017
```

### Kubernetes Dashboard

```bash
minikube dashboard
```

### Cleanup

```bash
# Stop Skaffold (Ctrl+C) - it will cleanup automatically

# Or manually cleanup
skaffold delete -f skaffold-local.yaml

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

### Production Deployment

For production/cloud deployments, use the production script:

```bash
# Deploy to production
./scripts/start-skaffold-prod.sh

# Deploy to staging
./scripts/start-skaffold-prod.sh --profile staging

# With port forwarding
./scripts/start-skaffold-prod.sh --port-forward
```

**See [SKAFFOLD_CONFIGS.md](../SKAFFOLD_CONFIGS.md) for complete production deployment guide.**

## Troubleshooting

### Docker Build Issues

**Problem**: Images not building in Minikube

**Solution**: Make sure Docker is using Minikube's daemon:
```bash
eval $(minikube docker-env)
docker ps  # Should work now
```

### Port Forwarding Issues

**Problem**: Ports already in use

**Solution**: Stop conflicting services or change ports in `skaffold-local.yaml`:
```yaml
portForward:
  - resourceType: service
    resourceName: backend-service
    port: 5000
    localPort: 5001  # Change to different port
```

### File Sync Not Working

**Problem**: File changes not syncing

**Solution**: 
1. Check sync rules in `skaffold-local.yaml`
2. Ensure files match the sync patterns
3. Restart Skaffold: `skaffold dev -f skaffold-local.yaml --port-forward`

### Kubernetes Connection Errors

**Problem**: "KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT must be defined"

**Solution**: 
1. Use `skaffold-local.yaml` for local development (not `skaffold.yaml`)
2. Use the helper script: `./scripts/start-skaffold-dev.sh`
3. The script automatically:
   - Unsets in-cluster config variables
   - Configures kubectl for Minikube
   - Sets proper KUBECONFIG

**See [SKAFFOLD_CONFIGS.md](../SKAFFOLD_CONFIGS.md) for detailed troubleshooting.**

### Minikube Not Starting

**Problem**: Minikube fails to start

**Solution**:
```bash
# Check Docker is running
docker ps

# Check WSL2 resources
# Increase memory/CPU in WSL2 settings if needed

# Try with more resources
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g
```

### Kubernetes Resources Not Deploying

**Problem**: Deployments stuck in pending

**Solution**:
```bash
# Check pod status
kubectl get pods

# Check events
kubectl get events

# Check node resources
kubectl describe node minikube
```

## Advanced Usage

### Custom Build Args

Edit `skaffold.yaml` to add build arguments:

```yaml
build:
  artifacts:
    - image: deepiri-cyrex
      docker:
        buildArgs:
          BUILD_TYPE: from-scratch
          PYTORCH_VERSION: 2.0.0
```

### Multiple Namespaces

```yaml
deploy:
  kubectl:
    flags:
      global: ['--namespace=deepiri-dev']
```

### Custom Sync Rules

Add more file patterns for sync:

```yaml
sync:
  '**/*.ts': /app/src/
  '**/*.tsx': /app/src/
  '**/*.css': /app/src/
```

## Comparison with Docker Compose

| Feature | Docker Compose | Skaffold + K8s |
|---------|---------------|----------------|
| Build caching | Basic | Advanced (BuildKit) |
| File sync | Manual volumes | Automatic sync |
| Dependency graph | Limited | Full understanding |
| Port forwarding | Manual | Automatic |
| Log streaming | Per service | All services |
| Cleanup | Manual | Automatic |
| Production ready | Limited | Full K8s |

## Next Steps

1. **Add more services**: Update `skaffold.yaml` to include frontend or other services
2. **Configure ingress**: Set up proper ingress for production-like routing
3. **Add monitoring**: Integrate Prometheus/Grafana for observability
4. **CI/CD integration**: Use Skaffold in your CI/CD pipeline

## Resources

- [Skaffold Documentation](https://skaffold.dev/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

