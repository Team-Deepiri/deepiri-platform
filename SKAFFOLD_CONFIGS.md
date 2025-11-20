# Skaffold Configuration Files

This project includes two Skaffold configuration files for different deployment scenarios:

## 📁 Configuration Files

### `skaffold-local.yaml` - Local Development (Minikube)
- **Purpose**: Local development with Minikube
- **Key Features**:
  - Explicitly uses kubeconfig (not in-cluster config)
  - Prevents "KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT must be defined" errors
  - Local builds (no push to registry)
  - File sync for fast development
  - Port forwarding enabled

### `skaffold-cloud.yaml` - Cloud/Production Deployments
- **Purpose**: Cloud deployments (GCP, AWS, Azure, etc.)
- **Key Features**:
  - Supports both kubeconfig (CI/CD) and in-cluster config (running in pods)
  - Pushes images to container registry
  - Production-optimized builds
  - Optional port forwarding

## 🚀 Usage Commands

### Local Development (Recommended)

**Using the helper script:**
```bash
# Linux/WSL2
./scripts/start-skaffold-dev.sh

# Windows PowerShell
.\scripts\start-skaffold-dev.ps1
```

**What the dev script does:**
- ✅ Checks Minikube is running
- ✅ Configures Docker to use Minikube's Docker daemon
- ✅ Configures kubectl to use Minikube context
- ✅ Unsets in-cluster config variables (prevents connection errors)
- ✅ Uses `skaffold-local.yaml` config
- ✅ Runs `skaffold dev` with port forwarding and file sync

**Direct Skaffold commands:**
```bash
# Start in dev mode (watch for changes)
skaffold dev -f skaffold-local.yaml --port-forward

# Run once (no watch)
skaffold run -f skaffold-local.yaml --port-forward

# Build only
skaffold build -f skaffold-local.yaml

# Deploy only (assumes images already built)
skaffold deploy -f skaffold-local.yaml
```

**With profiles:**
```bash
# Development profile (aggressive file sync)
skaffold dev -f skaffold-local.yaml --profile=dev --port-forward

# CPU profile (default, works everywhere)
skaffold dev -f skaffold-local.yaml --profile=cpu --port-forward

# GPU profile (requires NVIDIA GPU with CUDA)
skaffold dev -f skaffold-local.yaml --profile=gpu --port-forward
```

### Cloud/Production Deployments

**Prerequisites:**
- Set `KUBECONFIG` environment variable (for CI/CD) or use in-cluster config (if running in a pod)
- Configure container registry credentials
- Update `your-gcp-project-id` in `skaffold-cloud.yaml` if using Google Cloud Build

**Using the helper script:**
```bash
# Linux/WSL2
./scripts/start-skaffold-prod.sh                    # Deploy to production
./scripts/start-skaffold-prod.sh --profile staging   # Deploy to staging
./scripts/start-skaffold-prod.sh --port-forward       # Deploy with port forwarding
./scripts/start-skaffold-prod.sh --help              # Show help

# Windows PowerShell
.\scripts\start-skaffold-prod.ps1                                    # Deploy to production
.\scripts\start-skaffold-prod.ps1 -Profile staging                   # Deploy to staging
.\scripts\start-skaffold-prod.ps1 -Profile prod -PortForward         # Deploy with port forwarding
.\scripts\start-skaffold-prod.ps1 -Help                              # Show help
```

**What the prod script does:**
- ✅ Checks Kubernetes connection (kubeconfig or in-cluster)
- ✅ Uses `skaffold-cloud.yaml` config
- ✅ Runs `skaffold run` (not dev mode - no file watching)
- ✅ Supports profile selection (prod, staging, gpu)
- ✅ Optional port forwarding
- ✅ Confirmation prompt (unless in CI/CD)

**Direct Skaffold commands:**
```bash
# Deploy to production
skaffold run -f skaffold-cloud.yaml --profile=prod

# Deploy to staging
skaffold run -f skaffold-cloud.yaml --profile=staging

# Build and push images only
skaffold build -f skaffold-cloud.yaml --profile=prod

# Deploy only (assumes images already pushed)
skaffold deploy -f skaffold-cloud.yaml --profile=prod
```

**With CI/CD (example):**
```bash
# Set kubeconfig for CI/CD pipeline
export KUBECONFIG=/path/to/kubeconfig

# Deploy using script (skip confirmation in CI)
SKIP_CONFIRM=1 ./scripts/start-skaffold-prod.sh --profile prod

# Or directly
skaffold run -f skaffold-cloud.yaml --profile=prod
```

## 🔧 Troubleshooting

### "KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT must be defined"

**Problem**: Skaffold is trying to use in-cluster config instead of kubeconfig.

**Solution**: 
1. Use `skaffold-local.yaml` for local development
2. Ensure `KUBECONFIG` is set: `export KUBECONFIG=$HOME/.kube/config`
3. Unset in-cluster variables: `unset KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT`
4. Verify kubectl context: `kubectl config use-context minikube`

### "kubectl: executable file not found in $PATH"

**Problem**: kubectl is not installed or not in your PATH.

**Solution**: Install kubectl:
```bash
# Download and install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client

# Verify it's in PATH
which kubectl  # Should show /usr/local/bin/kubectl
```

**Note**: If `which kubectl` shows nothing, make sure `/usr/local/bin` is in your PATH:
```bash
echo $PATH | grep /usr/local/bin
# If not, add to ~/.bashrc or ~/.zshrc:
export PATH=$PATH:/usr/local/bin
```

### Minikube Connection Issues

```bash
# Check Minikube status
minikube status

# Start Minikube if not running
minikube start --driver=docker --cpus=4 --memory=8192

# Update kubectl context
minikube update-context

# Verify connection
kubectl cluster-info
```

### Cloud Deployment Issues

**If using kubeconfig:**
```bash
# Verify kubeconfig is set
echo $KUBECONFIG

# Test kubectl connection
kubectl cluster-info
```

**If using in-cluster config:**
- Ensure you're running inside a Kubernetes pod
- Verify service account has proper permissions
- Check that `KUBERNETES_SERVICE_HOST` and `KUBERNETES_SERVICE_PORT` are set

## 📝 Quick Reference

| Scenario | Script | Config File | Command |
|----------|--------|-------------|---------|
| Local dev (watch mode) | `./scripts/start-skaffold-dev.sh` | `skaffold-local.yaml` | `skaffold dev -f skaffold-local.yaml --port-forward` |
| Local dev (run once) | - | `skaffold-local.yaml` | `skaffold run -f skaffold-local.yaml --port-forward` |
| Cloud production | `./scripts/start-skaffold-prod.sh` | `skaffold-cloud.yaml` | `skaffold run -f skaffold-cloud.yaml --profile=prod` |
| Cloud staging | `./scripts/start-skaffold-prod.sh --profile staging` | `skaffold-cloud.yaml` | `skaffold run -f skaffold-cloud.yaml --profile=staging` |
| Build only (local) | - | `skaffold-local.yaml` | `skaffold build -f skaffold-local.yaml` |
| Build only (cloud) | - | `skaffold-cloud.yaml` | `skaffold build -f skaffold-cloud.yaml --profile=prod` |

## 🎯 Best Practices

1. **Local Development**: 
   - Always use `./scripts/start-skaffold-dev.sh` or `skaffold-local.yaml`
   - This avoids in-cluster config issues
   - Automatically configures Minikube and kubectl

2. **Production Deployments**:
   - Use `./scripts/start-skaffold-prod.sh` or `skaffold-cloud.yaml`
   - Set `KUBECONFIG` environment variable for CI/CD
   - Use `SKIP_CONFIRM=1` in CI/CD pipelines to skip confirmation prompts

3. **CI/CD Pipelines**: 
   - Use `skaffold-cloud.yaml` with `KUBECONFIG` environment variable
   - Example: `export KUBECONFIG=/path/to/kubeconfig && ./scripts/start-skaffold-prod.sh --profile prod`

4. **In-Cluster Deployments**: 
   - Use `skaffold-cloud.yaml` without `KUBECONFIG` (will use in-cluster config)
   - Ensure service account has proper permissions

5. **Profiles**: 
   - Use profiles to switch between CPU/GPU or dev/prod configurations
   - Local: `--profile=dev`, `--profile=cpu`, `--profile=gpu`
   - Cloud: `--profile=prod`, `--profile=staging`, `--profile=gpu`

6. **Helper Scripts**: 
   - Use `start-skaffold-dev.sh`/`.ps1` for local development
   - Use `start-skaffold-prod.sh`/`.ps1` for production deployments
   - Scripts handle all the configuration automatically

