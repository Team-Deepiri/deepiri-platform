# Quick Fix: Minikube Not Running

## Error
```
invalid skaffold config: getting minikube env: exit status 83
```

This means **Minikube is not running**.

## Fix

```bash
# 1. Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# 2. Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

# 3. Verify Minikube is running
minikube status

# 4. Now build with Skaffold
skaffold build -f skaffold/skaffold-local.yaml -p dev-compose
```

## Or Use the Helper Script

```bash
# This handles everything automatically
./scripts/build-with-skaffold-run-with-docker.sh
```

## Check Minikube Status

```bash
# Check if Minikube is running
minikube status

# If not running, start it
minikube start --driver=docker --cpus=4 --memory=8192

# Check Docker is pointing to Minikube
eval $(minikube docker-env)
docker info | grep "Docker Root Dir"  # Should show minikube path
```

