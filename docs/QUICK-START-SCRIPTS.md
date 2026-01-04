# 🚀 Quick Start - Command Reference

**⭐ PRIMARY METHOD: Use Skaffold for Kubernetes development**

Complete command reference for building, running, stopping, and managing Deepiri services.

---

## ⭐ PRIMARY: Skaffold (Kubernetes) Commands


### **Setup**

#### **Install Docker in WSL2 (Recommended - Not Docker Desktop)**

**Why use Docker Engine instead of Docker Desktop?**
- More reliable WSL2 integration (no socket connection issues)
- Better performance in WSL2
- Full control over Docker daemon

**Quick Install (Automated Script):**
```bash
# Run the automated installation script
# The script includes GPG key fingerprint verification for security
cd deepiri
./scripts/setup-docker-wsl2.sh

# After the script completes, restart WSL2:
# In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify installation
docker version
docker buildx version
docker ps
```

**What the script does:**
- Installs Docker Engine, Buildx, and Compose
- Verifies Docker's official GPG key fingerprint (security check)
- Configures WSL2 for systemd (required for Docker service)
- Sets up DNS configuration
- Adds your user to the docker group
- Handles repository errors gracefully (won't fail on broken repos like ROS)

**📝 Note about Intel Iris Xe Graphics:**
- Intel Iris Xe is an integrated GPU, not an NVIDIA GPU
- It does NOT support CUDA/PyTorch GPU acceleration
- Always use `--profile=cpu` with Intel Iris Xe
- The auto-detection script will automatically use CPU profile for Intel GPUs

**Manual Install (Alternative):**
```bash
# Installation dependencies
# Continue even if some repositories fail (e.g., ROS repository)
sudo apt update || true
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key (using docker.asc as per official Docker docs)
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Verify Docker GPG key fingerprint (optional but recommended)
# Official Docker GPG key fingerprint: 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88
if command -v gpg >/dev/null 2>&1; then
    EXPECTED_FP="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
    KEY_FP=$(sudo gpg --show-keys --with-fingerprint /etc/apt/keyrings/docker.asc 2>/dev/null | \
        grep -A1 "^pub" | grep -i "fingerprint" | sed 's/.*fingerprint = //' | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    if [ "$KEY_FP" = "$EXPECTED_FP" ]; then
        echo "✅ Docker GPG key fingerprint verified"
    else
        echo "⚠️  Warning: Fingerprint verification failed, but continuing..."
    fi
fi

# Add Docker repository
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine (with Buildx and Compose)
# Continue even if some repositories fail
sudo apt update || true
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Configure WSL2 for systemd (required for Docker service)
sudo bash -c "cat >> /etc/wsl.conf <<EOL
[boot]
systemd=true

[network]
generateResolvConf=false
EOL"

# Configure DNS for better container connectivity (optional)
if ! grep -q "1.1.1.1" /etc/resolv.conf; then
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak
    echo -e "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
fi

# Restart WSL2: In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify installation
docker version
docker buildx version
docker ps
```

#### **Install Minikube**

```bash
# Download and Install Minikube (first time only)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version    # Verify

# IMPORTANT: Make sure Docker is running first!
# Verify Docker is working: docker ps

# Then setup Minikube (only when minikube isn't started or first setup)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env) # This is important for Minikube to see Docker images built on your device.

# Or use setup script (checks Docker first)
./scripts/setup-minikube-wsl2.sh      # Linux/WSL2
.\scripts\setup-minikube-wsl2.ps1     # Windows PowerShell
```

**⚠️ Important:** 
- Make sure Docker is installed and running (use `docker ps` to verify)
- If using Docker Engine (not Docker Desktop), ensure the service is running: `sudo systemctl status docker`

### **Build**


```bash
# Install Skaffold
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/
skaffold version   # Verify
```
## If you get a permissions error
Run:

```bash
chmod +x skaffold
sudo install skaffold /usr/local/bin/
```

```bash
# SIMPLIFIED: Use the auto-detection script (recommended)
cd deepiri
./scripts/skaffold-build.sh        # Auto-detects GPU/CPU
./scripts/skaffold-build.sh cpu   # Force CPU profile
./scripts/skaffold-build.sh gpu   # Force GPU profile (NVIDIA only)

# OR manually:
# 1. Make sure Minikube is running
minikube status || minikube start --driver=docker --cpus=4 --memory=8192

# 2. Configure Docker to use Minikube's Docker daemon (REQUIRED!)
eval $(minikube docker-env)

# 3. Build all services (auto-detects GPU/CPU)
skaffold build --profile=cpu   # CPU profile (works everywhere, including Intel Iris Xe)
skaffold build --profile=gpu   # GPU profile (NVIDIA GPU with 4GB+ VRAM only)

# Build specific service
skaffold build --artifact=deepiri-core-api
skaffold build --artifact=deepiri-cyrex

# Force rebuild (no cache)
skaffold build --profile=cpu --no-cache
```

**⚠️ GPU Support Notes:**
- **NVIDIA GPUs**: Use `--profile=gpu` if you have NVIDIA GPU with 4GB+ VRAM
- **Intel Iris Xe Graphics**: Not supported for GPU acceleration (use `--profile=cpu`)
- **Other integrated GPUs**: Use `--profile=cpu` (CPU profile)
- The script auto-detects and uses the correct profile

### **Run**

```bash
# Start with Skaffold (builds, deploys, port-forwards, streams logs)
skaffold dev --port-forward

# Or use helper script
./scripts/start-skaffold-dev.sh        # Linux/WSL2
.\scripts\start-skaffold-dev.ps1      # Windows PowerShell

# Run once (no watch mode)
skaffold run --port-forward
```

### **Stop**

```bash
# Press Ctrl+C in Skaffold terminal (auto-cleanup)

# Or manually cleanup:
./scripts/stop-skaffold.sh             # Linux/WSL2
.\scripts\stop-skaffold.ps1            # Windows PowerShell

# Or use Skaffold directly
skaffold delete
```

### **Check Logs**

```bash
# Skaffold streams logs automatically in dev mode
# Or view logs manually:

# All pods for a service
kubectl logs -f -l app=deepiri-core-api
kubectl logs -f -l app=deepiri-cyrex

# Specific deployment
kubectl logs -f deployment/deepiri-core-api
kubectl logs -f deployment/deepiri-cyrex
kubectl logs -f deployment/mongodb
kubectl logs -f deployment/redis

# Specific pod
kubectl get pods                    # List pods
kubectl logs -f <pod-name>          # View pod logs

# Last 100 lines
kubectl logs --tail=100 deployment/deepiri-core-api

# Previous container (if pod restarted)
kubectl logs -f --previous deployment/deepiri-core-api
```

### **Check Status**

```bash
# Pod status
kubectl get pods

# Service status
kubectl get services

# Deployment status
kubectl get deployments

# Detailed pod info
kubectl describe pod <pod-name>

# Resource usage
kubectl top pods
```

### **Restart Services**

```bash
# Restart deployment
kubectl rollout restart deployment/deepiri-core-api
kubectl rollout restart deployment/deepiri-cyrex

# Scale deployment
kubectl scale deployment/deepiri-core-api --replicas=2
```

### **Access Service Shell**

```bash
# Get shell in pod
kubectl exec -it deployment/deepiri-core-api -- sh
kubectl exec -it deployment/deepiri-cyrex -- sh
```

### **Kubernetes Dashboard**

```bash
# Open dashboard
minikube dashboard
```

---

## 🐳 Alternative: Docker Compose Commands

### **Build**

```bash
# Full rebuild (removes old images, rebuilds fresh)
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows PowerShell

# Rebuild specific service
docker compose -f docker-compose.dev.yml build --no-cache <service-name>

# Rebuild all services (without removing old images)
docker compose -f docker-compose.dev.yml build
```

### **Run**

```bash
# Start all services (uses existing images - fast!)
docker compose -f docker-compose.dev.yml up -d

# Start specific service
docker compose -f docker-compose.dev.yml up -d <service-name>

# Start and view logs in terminal
docker compose -f docker-compose.dev.yml up
```

### **Stop**

```bash
# Stop all services (keeps containers)
docker compose -f docker-compose.dev.yml stop

# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Stop and remove containers + volumes (WARNING: Deletes data!)
docker compose -f docker-compose.dev.yml down -v
```

### **Check Logs**

```bash
# All services (follow mode)
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f <service-name>

# Last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100

# Examples:
docker compose -f docker-compose.dev.yml logs -f backend
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f mongodb
```

### **Check Status**

```bash
# List all running containers
docker compose -f docker-compose.dev.yml ps

# Resource usage
docker stats
```

### **Restart Services**

```bash
# Restart all services
docker compose -f docker-compose.dev.yml restart

# Restart specific service
docker compose -f docker-compose.dev.yml restart <service-name>
```

### **Access Service Shell**

```bash
# Get shell in container
docker compose -f docker-compose.dev.yml exec <service-name> sh
docker compose -f docker-compose.dev.yml exec backend sh
docker compose -f docker-compose.dev.yml exec cyrex sh
```

---

## 🧹 Cleanup Commands

### **Skaffold Cleanup**

```bash
# Delete all resources
skaffold delete

# Clean up Minikube
minikube stop
minikube delete  # WARNING: Deletes cluster and all data
```

### **Docker Compose Cleanup**

```bash
# Stop and remove everything
docker compose -f docker-compose.dev.yml down -v

# Remove old images (frees up ~50GB)
./rebuild.sh              # Linux/Mac (removes old images, rebuilds fresh)
.\rebuild.ps1             # Windows PowerShell

# Just free up space (keep current images)
./scripts/docker-cleanup.sh
```

### **Docker System Cleanup**

```bash
# Remove unused containers, networks, images
docker system prune

# Remove all unused images (not just dangling)
docker system prune -a

# Remove volumes
docker volume prune
```

### **WSL Disk Cleanup (Windows)**

```bash
# Compact WSL disk (if Windows showing low space)
# 1. Exit WSL
# 2. Double-click: scripts/compact-wsl-disk.bat
```

---

## 📋 Most Common Tasks

### **⭐ Fresh Start with Skaffold (Recommended)**

```bash
# 1. Setup (first time only)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# 2. Start everything
skaffold dev --port-forward
```

### **Fresh Rebuild with Docker Compose**

**When:** You have lots of old Docker images (~50GB) and want a clean rebuild

**From WSL:**
```bash
./rebuild.sh              # Linux/Mac
```

**From Windows (double-click):**
```
rebuild.ps1
```

**What it does:**
1. ✅ Stops all containers
2. ✅ Deletes all old `deepiri-dev-*` images (~50GB)
3. ✅ Cleans build cache
4. ✅ Rebuilds everything fresh (no cache)
5. ✅ Starts all services

**Time:** 10-30 minutes (depending on your internet speed)

### **Just Start Services (No Rebuild)**

**Skaffold:**
```bash
skaffold dev --port-forward
```

**Docker Compose:**
```bash
docker compose -f docker-compose.dev.yml up -d
```

### **Just Stop Services**

**Skaffold:**
```bash
# Press Ctrl+C in Skaffold terminal
# Or:
skaffold delete
```

**Docker Compose:**
```bash
docker compose -f docker-compose.dev.yml down
```

### **View Logs**

**Skaffold:**
```bash
# Auto-streams in dev mode, or:
kubectl logs -f deployment/deepiri-core-api
```

**Docker Compose:**
```bash
docker compose -f docker-compose.dev.yml logs -f
```

---

## 🔧 Service-Specific Commands

### **Backend Service**

**Skaffold:**
```bash
# Logs
kubectl logs -f deployment/deepiri-core-api

# Restart
kubectl rollout restart deployment/deepiri-core-api

# Shell
kubectl exec -it deployment/deepiri-core-api -- sh
```

**Docker Compose:**
```bash
# Logs
docker compose -f docker-compose.dev.yml logs -f backend

# Restart
docker compose -f docker-compose.dev.yml restart backend

# Shell
docker compose -f docker-compose.dev.yml exec backend sh
```

### **Cyrex (AI Service)**

**Skaffold:**
```bash
# Logs
kubectl logs -f deployment/deepiri-cyrex

# Restart
kubectl rollout restart deployment/deepiri-cyrex

# Shell
kubectl exec -it deployment/deepiri-cyrex -- sh
```

**Docker Compose:**
```bash
# Logs
docker compose -f docker-compose.dev.yml logs -f cyrex

# Restart
docker compose -f docker-compose.dev.yml restart cyrex

# Shell
docker compose -f docker-compose.dev.yml exec cyrex sh
```

### **MongoDB**

**Skaffold:**
```bash
# Logs
kubectl logs -f deployment/mongodb

# Shell
kubectl exec -it deployment/mongodb -- mongosh
```

**Docker Compose:**
```bash
# Logs
docker compose -f docker-compose.dev.yml logs -f mongodb

# Shell
docker compose -f docker-compose.dev.yml exec mongodb mongosh
```

### **Redis**

**Skaffold:**
```bash
# Logs
kubectl logs -f deployment/redis

# Shell
kubectl exec -it deployment/redis -- redis-cli
```

**Docker Compose:**
```bash
# Logs
docker compose -f docker-compose.dev.yml logs -f redis

# Shell
docker compose -f docker-compose.dev.yml exec redis redis-cli
```

---

## 🆘 Troubleshooting Commands

### **Port Already in Use**

```bash
# Windows
netstat -ano | findstr :5000
taskkill /PID <pid> /F

# macOS/Linux
lsof -i :5000
kill -9 <pid>
```

### **Docker Issues**

```bash
# For Docker Compose:
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d

# For Skaffold - Check Docker is using Minikube's daemon:
# 1. Make sure Docker Desktop is running
# 2. Then:
eval $(minikube docker-env)
docker ps  # Verify it works

# If Docker Desktop is running but docker ps fails:
# Unset Minikube Docker env first, then check host Docker
unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD
docker ps  # Should work if Docker Desktop is running
```

### **Kubernetes Pods Not Starting**

```bash
# Check pod status
kubectl get pods

# Check pod logs
kubectl logs <pod-name>

# Check pod events
kubectl describe pod <pod-name>

# Check ConfigMap/Secrets
kubectl get configmap deepiri-config
kubectl get secret deepiri-secrets
```

### **Common Issues**

**"dumb-init not found"** → Run `./rebuild.sh` or `.\rebuild.ps1`

**"No space left"** → Run `./rebuild.sh` then `scripts/compact-wsl-disk.bat`

**Container won't start** → Check logs:
- Skaffold: `kubectl logs <pod-name>`
- Docker Compose: `docker compose -f docker-compose.dev.yml logs <service-name>`

**Docker not building in Minikube?**
```bash
# Make sure Docker Desktop is running first
# Then:
eval $(minikube docker-env)
docker ps  # Verify it works

# If that doesn't work, restart Minikube:
minikube stop
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)
```

**Ports already in use?**
- Skaffold: Edit `skaffold.yaml` to change `localPort` values
- Docker Compose: Change ports in `docker-compose.dev.yml`

**Files not syncing (Skaffold)?**
Check sync patterns in `skaffold.yaml` match your file types.

---

## 📚 Quick Reference

### **Service URLs**

| Service | URL | Method |
|---------|-----|--------|
| **Backend** | http://localhost:5000 | Both |
| **Cyrex** | http://localhost:8000 | Both |
| **MongoDB** | localhost:27017 | Both |
| **Redis** | localhost:6379 | Both |
| **LocalAI** | http://localhost:8080 | Both |
| **Frontend** | http://localhost:5173 | Docker Compose only |

### **Helper Scripts**

| Script | Purpose | Platform |
|--------|---------|----------|
| `setup-minikube-wsl2.sh` | Setup Minikube | Linux/WSL2 |
| `setup-minikube-wsl2.ps1` | Setup Minikube | Windows PowerShell |
| `start-skaffold-dev.sh` | Start Skaffold | Linux/WSL2 |
| `start-skaffold-dev.ps1` | Start Skaffold | Windows PowerShell |
| `stop-skaffold.sh` | Stop Skaffold | Linux/WSL2 |
| `stop-skaffold.ps1` | Stop Skaffold | Windows PowerShell |
| `rebuild.sh` | Rebuild Docker images | Linux/Mac |
| `rebuild.ps1` | Rebuild Docker images | Windows PowerShell |
| `docker-cleanup.sh` | Clean Docker space | Linux/Mac |
| `compact-wsl-disk.bat` | Compact WSL disk | Windows |

---

## 📖 Full Documentation

- **Skaffold Setup:** [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md)
- **Skaffold Quick Start:** [SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)
- **Getting Started:** [GETTING_STARTED.md](GETTING_STARTED.md)
- **Start Everything:** [START_EVERYTHING.md](START_EVERYTHING.md)
- **Troubleshooting:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Scripts Documentation:** `scripts/README.md`

---

**Last Updated:** 2024  
**Primary Method:** Skaffold (Kubernetes) ⭐
