# Hybrid Workflow: Build with Skaffold, Run with Docker Compose

## 🎯 Best of Both Worlds

This workflow combines:
- **Skaffold** for building (uses Minikube's Docker daemon, consistent with K8s)
- **Docker Compose** for running (fastest startup, ~5-10 seconds)

## ⚡ Quick Start

### One-Command Workflow

```bash
# Build with Skaffold, then run with Docker Compose
./scripts/build-with-skaffold-run-with-docker.sh        # Linux/WSL
.\scripts\build-with-skaffold-run-with-docker.ps1       # Windows
```

### Manual Steps

```bash
# 1. Ensure prerequisites
kubectl version --client
minikube status
skaffold version

# 2. Start Minikube (if not running)
minikube start --driver=docker --cpus=4 --memory=8192

# 3. Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

# 4. Build with Skaffold
skaffold build -f skaffold-local.yaml

# 5. Tag images for Docker Compose (if needed)
docker tag deepiri-cyrex:latest deepiri-dev-cyrex:latest
docker tag deepiri-api-gateway:latest deepiri-dev-api-gateway:latest
# ... (script handles this automatically)

# 6. Run with Docker Compose (keep using Minikube's Docker daemon)
docker compose -f docker-compose.dev.yml up -d
```

## 📋 What the Script Does

1. ✅ **Checks prerequisites:**
   - kubectl installed
   - Minikube running
   - Skaffold installed
   - Docker Compose available

2. ✅ **Configures Docker:**
   - Points Docker to Minikube's Docker daemon
   - Verifies connection

3. ✅ **Builds with Skaffold:**
   - Builds all images using Minikube's Docker daemon
   - Images are stored in Minikube's Docker registry

4. ✅ **Tags images:**
   - Tags Skaffold-built images to match Docker Compose names
   - Example: `deepiri-cyrex:latest` → `deepiri-dev-cyrex:latest`

5. ✅ **Runs with Docker Compose:**
   - Starts all services using Docker Compose
   - Uses images from Minikube's Docker daemon
   - Fast startup (~5-10 seconds)

## 🚀 Benefits

- **Consistent builds:** Uses same Docker daemon as Kubernetes
- **Fast startup:** Docker Compose is faster than Kubernetes deployment
- **Best of both:** Skaffold's build system + Docker Compose's speed

## 📊 Speed Comparison

| Step | Method | Time |
|------|--------|------|
| **Build** | Skaffold | ~5-15 min (first time) |
| **Run** | Docker Compose | ~5-10 seconds ⚡ |
| **Total** | Hybrid | Fastest after first build |

## 🔧 Troubleshooting

### Images Not Found

If Docker Compose can't find images:

```bash
# Make sure Docker is using Minikube's Docker daemon
eval $(minikube docker-env)

# Check images are available
docker images | grep deepiri

# Manually tag if needed
docker tag deepiri-cyrex:latest deepiri-dev-cyrex:latest
```

### Minikube Not Running

```bash
# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker
eval $(minikube docker-env)
```

### kubectl Not Found

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## 📝 Commands Reference

### Build Only
```bash
eval $(minikube docker-env)
skaffold build -f skaffold-local.yaml
```

### Run Only (After Build)
```bash
# Keep using Minikube's Docker daemon
eval $(minikube docker-env)

# Start with Docker Compose
docker compose -f docker-compose.dev.yml up -d
```

### View Logs
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Stop
```bash
docker compose -f docker-compose.dev.yml down
```

## 💡 Pro Tips

1. **Build once, run many:** Build with Skaffold once, then use Docker Compose for quick restarts
2. **Keep Docker env:** Stay in Minikube's Docker daemon for both build and run
3. **Check images:** Use `docker images | grep deepiri` to verify images exist
4. **Tag manually:** If auto-tagging fails, tag images manually before running Docker Compose

