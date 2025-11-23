# Quick Fix: Use Skaffold-Built Images with Docker Compose

## Problem
When you run `docker compose -f docker-compose.dev.yml up -d`, it's **pulling** images from Docker Hub instead of using the images you built with Skaffold.

## Solution: Point Docker to Minikube's Docker Daemon

The images built by Skaffold are in **Minikube's Docker daemon**, not your host Docker daemon.

### Quick Fix

```bash
# 1. Make sure Docker is pointing to Minikube's Docker daemon
eval $(minikube docker-env)

# 2. Verify Docker can see Minikube's images
docker images | grep deepiri

# 3. Now run Docker Compose (it will use Minikube's images)
docker compose -f docker-compose.dev.yml up -d
```

### What's Happening

- **Without `eval $(minikube docker-env)`:**
  - Docker Compose uses **host Docker daemon**
  - Images built by Skaffold are in **Minikube's Docker daemon**
  - Docker Compose can't find them → tries to pull from registry

- **With `eval $(minikube docker-env)`:**
  - Docker Compose uses **Minikube's Docker daemon**
  - Images built by Skaffold are available
  - Docker Compose uses existing images → fast startup!

## Check Current Docker Daemon

```bash
# Check which Docker daemon you're using
docker info | grep "Docker Root Dir"

# If it shows something like /var/lib/docker, you're using host Docker
# If it shows something with minikube, you're using Minikube's Docker
```

## Full Workflow

```bash
# 1. Build with Skaffold (images go to Minikube's Docker)
eval $(minikube docker-env)
skaffold build -f skaffold-local.yaml

# 2. Run with Docker Compose (keep using Minikube's Docker)
# (Docker is already pointing to Minikube from step 1)
docker compose -f docker-compose.dev.yml up -d
```

## Or Use the Hybrid Script

```bash
# This handles everything automatically
./scripts/build-with-skaffold-run-with-docker.sh
```

