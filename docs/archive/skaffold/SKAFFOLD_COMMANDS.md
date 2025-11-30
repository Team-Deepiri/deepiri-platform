# Hybrid Workflow Commands - Build with Skaffold, Run with Docker Compose

## 🎯 One-Command Solution

```bash
# Linux/WSL
./scripts/build-with-skaffold-run-with-docker.sh

# Windows PowerShell
.\scripts\build-with-skaffold-run-with-docker.ps1
```

## 📋 Manual Step-by-Step Commands

### Step 1: Check Prerequisites

```bash
# Check kubectl
kubectl version --client

# If not installed:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Step 2: Ensure Minikube is Running

```bash
# Check status
minikube status

# If not running, start it
minikube start --driver=docker --cpus=4 --memory=8192
```

### Step 3: Configure Docker to Use Minikube's Docker Daemon

```bash
# This is CRITICAL - Docker must point to Minikube's Docker daemon
eval $(minikube docker-env)

# Verify it works
docker ps
```

### Step 4: Build with Skaffold

```bash
# Build all images (uses Minikube's Docker daemon)
skaffold build -f skaffold-local.yaml
```

### Step 5: Tag Images for Docker Compose (if needed)

```bash
# Tag Skaffold images to match Docker Compose names
docker tag deepiri-cyrex:latest deepiri-dev-cyrex:latest
docker tag deepiri-api-gateway:latest deepiri-dev-api-gateway:latest
docker tag deepiri-auth-service:latest deepiri-dev-auth-service:latest
docker tag deepiri-task-orchestrator:latest deepiri-dev-task-orchestrator:latest
docker tag deepiri-challenge-service:latest deepiri-dev-challenge-service:latest
docker tag deepiri-engagement-service:latest deepiri-dev-engagement-service:latest
docker tag deepiri-platform-analytics-service:latest deepiri-dev-platform-analytics-service:latest
docker tag deepiri-external-bridge-service:latest deepiri-dev-external-bridge-service:latest
docker tag deepiri-notification-service:latest deepiri-dev-notification-service:latest
docker tag deepiri-realtime-gateway:latest deepiri-dev-realtime-gateway:latest
docker tag deepiri-frontend:latest deepiri-dev-frontend:latest
```

**Note:** The script handles this automatically, but you can do it manually if needed.

### Step 6: Run with Docker Compose

```bash
# Keep using Minikube's Docker daemon (images are already there!)
# Docker Compose will use the images from Minikube's Docker daemon

docker compose -f docker-compose.dev.yml up -d
```

## ✅ Verification

```bash
# Check services are running
docker compose -f docker-compose.dev.yml ps

# View logs
docker compose -f docker-compose.dev.yml logs -f

# Check images exist
docker images | grep deepiri
```

## 🛑 Stopping

```bash
# Stop Docker Compose services
docker compose -f docker-compose.dev.yml down

# (Optional) Switch back to host Docker
unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD
```

## 🔄 Quick Restart (After Build)

Once images are built, you can restart quickly:

```bash
# Ensure Docker is using Minikube's Docker daemon
eval $(minikube docker-env)

# Start services (fast!)
docker compose -f docker-compose.dev.yml up -d
```

## 💡 Key Points

1. **Always use Minikube's Docker daemon:** `eval $(minikube docker-env)`
2. **Build once with Skaffold:** Images are stored in Minikube's Docker
3. **Run many times with Docker Compose:** Fast startup using pre-built images
4. **Keep Docker env:** Don't switch back to host Docker - keep using Minikube's

## 📚 See Also

- **[HYBRID_WORKFLOW.md](HYBRID_WORKFLOW.md)** - Detailed guide
- **[COMMANDS_REFERENCE.md](COMMANDS_REFERENCE.md)** - All commands
- **[SPEED_COMPARISON.md](SPEED_COMPARISON.md)** - Speed comparison

