# 🚀 Complete Setup Guide - Deepiri

**This is the definitive guide for setting up and running the entire Deepiri project from scratch.**

This guide covers:
- ✅ All prerequisites and dependencies
- ✅ Complete environment setup
- ✅ Building all services
- ✅ Running the entire stack
- ✅ Verification and testing

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

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Initial Setup](#initial-setup)
4. [Docker Setup](#docker-setup)
5. [Kubernetes Setup (Skaffold)](#kubernetes-setup-skaffold)
6. [Environment Configuration](#environment-configuration)
7. [Building All Services](#building-all-services)
8. [Running the Application](#running-the-application)
9. [Verification](#verification)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

Before starting, ensure you have the following installed:

| Software | Version | Purpose |
|----------|---------|---------|
| **Docker** | 20.10+ | Container runtime |
| **Docker Compose** | 2.0+ | Multi-container orchestration |
| **Minikube** | Latest | Local Kubernetes cluster |
| **Skaffold** | Latest | Kubernetes development tool |
| **kubectl** | Latest | Kubernetes CLI |
| **Git** | 2.30+ | Version control |
| **Node.js** | 20.x+ | Frontend and backend services |
| **Python** | 3.11+ | AI/ML services (optional for local dev) |

### Required Accounts & API Keys

- **OpenAI API Key** (or Anthropic API Key) - for AI features
- **MongoDB Atlas** (optional) - cloud database, or use local MongoDB
- **Firebase Account** (optional) - for authentication
- **GitHub Account** - for repository access

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker-compose --version

# Check Kubernetes tools
minikube version
kubectl version --client
skaffold version

# Check Node.js (should be 20.x or higher)
node --version
npm --version

# Check Python (should be 3.11+)
python3 --version

# Check Git
git --version
```

---

## System Requirements

### Minimum Requirements

- **RAM:** 8GB (16GB+ recommended)
- **Storage:** 50GB+ free space
- **CPU:** 4 cores (8+ recommended)
- **OS:** 
  - Windows 10+ with WSL2 (recommended)
  - Linux (Ubuntu 20.04+)
  - macOS 10.15+

### GPU Requirements (Optional)

- **For GPU acceleration:** NVIDIA GPU with CUDA 11.8+
- **For CPU-only builds:** Any modern CPU (Intel Iris Xe, AMD, etc.)
- **Note:** Intel Iris Xe Graphics does NOT support CUDA - use CPU profile

---

## Initial Setup

### 1. Clone the Repository

```bash
# Clone the repository
git clone <repository-url>
cd Deepiri/deepiri

# Verify you're in the correct directory
ls -la
# You should see: skaffold.yaml, docker-compose.yml, platform-services/, etc.
```

### 2. Install System Dependencies

**For WSL2/Ubuntu/Debian:**

```bash
# Update package list
sudo apt update

# Install essential build tools
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release
```

**For macOS:**

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install curl wget git
```

---

## Docker Setup

### ⭐ Recommended: Docker Engine in WSL2

**Why Docker Engine instead of Docker Desktop?**
- More reliable WSL2 integration
- Better performance
- Full control over Docker daemon
- No socket connection issues

### Automated Installation (Recommended)

```bash
# Navigate to project root
cd deepiri

# Run the automated installation script
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
- ✅ Installs Docker Engine, Buildx, and Compose
- ✅ Verifies Docker's official GPG key fingerprint (security)
- ✅ Configures WSL2 for systemd
- ✅ Sets up DNS configuration
- ✅ Adds your user to the docker group
- ✅ Handles repository errors gracefully

### Manual Installation

See [QUICK-START-SCRIPTS.md](QUICK-START-SCRIPTS.md) for detailed manual installation steps.

### Verify Docker is Running

```bash
# Check Docker service status
sudo systemctl status docker

# Test Docker
docker run hello-world

# Verify Docker Compose
docker compose version
```

---

## Kubernetes Setup (Skaffold)

### 1. Install Minikube

```bash
# Download Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version

# Or use the setup script
./scripts/setup-minikube-wsl2.sh
```

### 2. Install kubectl

```bash
# Download and install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

**⚠️ Important:** kubectl is required for Skaffold to deploy to Kubernetes. If you get "kubectl: executable file not found in $PATH" errors, make sure kubectl is installed and in your PATH.

### 3. Install Skaffold

```bash
# Download Skaffold
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/skaffold
skaffold version

# Or install via package manager
# For Ubuntu/Debian:
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/skaffold
```

### 4. Start Minikube

```bash
# IMPORTANT: Make sure Docker is running first!
docker ps

# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

# Verify Minikube is running
minikube status
kubectl get nodes
```

**⚠️ Important Notes:**
- Minikube requires Docker to be running
- The `eval $(minikube docker-env)` command points Docker CLI to Minikube's daemon
- You need to run this in every new terminal session, or add it to your shell profile

---

## Environment Configuration

### 1. Copy Environment Files

```bash
# Navigate to project root
cd deepiri

# Copy example environment files
cp env.example .env

# Copy service-specific environment files
cp deepiri-core-api/env.example.api-server .env.deepiri-core-api 2>/dev/null || true
cp diri-cyrex/env.example.diri-cyrex .env.diri-cyrex 2>/dev/null || true
cp deepiri-web-frontend/env.example.frontend .env.deepiri-web-frontend 2>/dev/null || true
```

### 2. Configure Environment Variables

Edit `.env` file with your configuration:

```bash
# Required API Keys
OPENAI_API_KEY=your-openai-api-key-here
# OR
ANTHROPIC_API_KEY=your-anthropic-api-key-here

# Database Configuration
MONGO_ROOT_PASSWORD=your-secure-password
MONGO_DATABASE=deepiri

# Redis Configuration
REDIS_PASSWORD=your-redis-password

# Firebase (Optional)
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=your-firebase-private-key
FIREBASE_CLIENT_EMAIL=your-firebase-client-email

# Frontend Environment Variables
VITE_API_URL=http://localhost:5000
VITE_FIREBASE_API_KEY=your-firebase-api-key
VITE_FIREBASE_AUTH_DOMAIN=your-firebase-auth-domain
VITE_FIREBASE_PROJECT_ID=your-firebase-project-id
```

**📝 Note:** For detailed environment variable reference, see [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)

### 3. Firebase Configuration (Optional)

If using Firebase, you have two options:

**Option A: JSON File (for local development)**
- Place Firebase service account JSON files in:
  - `deepiri-core-api/config/tripblip-mag-firebase-adminsdk-*.json`
  - `deepiri-core-api/src/config/tripblip-firebase-adminsdk-*.json`

**Option B: Environment Variables (recommended for Docker/K8s)**
- Set `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`, etc. in `.env`
- The code will automatically use environment variables if JSON files are missing

---

## Building All Services

### ⭐ Primary Method: Build with Skaffold

Skaffold will build all services automatically:

```bash
# Navigate to project root
cd deepiri

# Make sure Minikube is running and Docker is configured
minikube status
eval $(minikube docker-env)

# Auto-detect GPU and build (recommended)
./scripts/skaffold-build.sh

# Or specify profile manually
./scripts/skaffold-build.sh cpu    # For CPU-only builds (Intel Iris Xe, etc.)
./scripts/skaffold-build.sh gpu    # For NVIDIA GPU builds
```

**What gets built:**
- ✅ `deepiri-core-api` - Main API server
- ✅ `deepiri-cyrex` - AI/ML service
- ✅ `deepiri-frontend` - React frontend
- ✅ `deepiri-api-gateway` - API Gateway
- ✅ `deepiri-auth-service` - Authentication service
- ✅ `deepiri-task-orchestrator` - Task orchestration
- ✅ `deepiri-challenge-service` - Challenge service
- ✅ `deepiri-engagement-service` - Engagement service
- ✅ `deepiri-platform-analytics-service` - Analytics service
- ✅ `deepiri-external-bridge-service` - External integrations
- ✅ `deepiri-notification-service` - Notifications
- ✅ `deepiri-realtime-gateway` - WebSocket gateway

### Manual Build (Alternative)

If you prefer to build manually:

```bash
# Build all services with Skaffold
skaffold build --profile=cpu

# Or for GPU
skaffold build --profile=gpu
```

### Build Individual Services

```bash
# Build specific service
docker build -t deepiri-core-api ./deepiri-core-api
docker build -t deepiri-frontend ./deepiri-web-frontend
docker build -t deepiri-cyrex ./diri-cyrex
```

---

## Running the Application

### ⭐ Primary Method: Run with Skaffold

**Start all services:**

```bash
# Navigate to project root
cd deepiri

# Ensure Minikube is running
minikube status || minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker for Minikube
eval $(minikube docker-env)

# Start all services with Skaffold
skaffold dev --profile=cpu

# Or use the start script
./scripts/start-skaffold-dev.sh cpu
```

**What happens:**
- ✅ Builds all Docker images
- ✅ Deploys all services to Minikube
- ✅ Sets up service networking
- ✅ Watches for code changes and rebuilds
- ✅ Streams logs from all services

### Access the Application

```bash
# Get Minikube IP
minikube ip

# Get service URLs
minikube service list

# Access frontend
minikube service deepiri-frontend

# Access API
minikube service deepiri-core-api

# Or use port forwarding
kubectl port-forward service/deepiri-frontend 3000:80
kubectl port-forward service/deepiri-core-api 5000:5000
```

### Alternative: Docker Compose

If you prefer Docker Compose (simpler, but not Kubernetes):

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Verification

### 1. Check All Services are Running

```bash
# Check Kubernetes pods
kubectl get pods

# Check services
kubectl get services

# Check deployments
kubectl get deployments

# View logs
kubectl logs -f deployment/deepiri-core-api
kubectl logs -f deployment/deepiri-frontend
```

### 2. Test API Endpoints

```bash
# Health check
curl http://localhost:5000/api/health

# Or via Minikube
curl $(minikube service deepiri-core-api --url)/api/health
```

### 3. Access Frontend

Open your browser and navigate to:
- **Frontend:** http://localhost:3000 (or Minikube service URL)
- **API:** http://localhost:5000 (or Minikube service URL)

### 4. Verify Database Connection

```bash
# Check MongoDB connection
kubectl exec -it deployment/deepiri-core-api -- npm run test:db

# Or check logs for connection messages
kubectl logs deployment/deepiri-core-api | grep -i mongo
```

---

## Troubleshooting

### Common Issues

#### 1. Docker Daemon Not Running

```bash
# Check Docker status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker
```

#### 2. Minikube Won't Start

```bash
# Check Docker is running
docker ps

# Delete and recreate Minikube
minikube delete
minikube start --driver=docker --cpus=4 --memory=8192
```

#### 3. Build Failures

```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
skaffold build --profile=cpu --no-cache

# Check build logs
skaffold build --profile=cpu --verbosity=debug
```

#### 4. Port Already in Use

```bash
# Find process using port
lsof -i :5000
# Or
netstat -tulpn | grep :5000

# Kill process or change port in configuration
```

#### 5. TypeScript Build Errors

If you see TypeScript errors during build:
- Check Node.js version (should be 20.x+)
- Verify `tsconfig.json` settings
- Some type errors are warnings and won't block the build

#### 6. GPU Detection Issues

```bash
# Check GPU
nvidia-smi

# Force CPU profile
./scripts/skaffold-build.sh cpu

# For Intel Iris Xe Graphics, always use CPU profile
```

### Getting Help

- **Documentation:** See [docs/](docs/) for team-specific guides
- **Troubleshooting Guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Quick Start:** [QUICK-START-SCRIPTS.md](QUICK-START-SCRIPTS.md)
- **Skaffold Guide:** [SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)

---

## Next Steps

After completing setup:

1. **Read Team-Specific Guides:**
   - [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md)
   - [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md)
   - [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)
   - [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)

2. **Explore the Codebase:**
   - `deepiri-core-api/` - Main API server
   - `deepiri-web-frontend/` - React frontend
   - `diri-cyrex/` - AI/ML service
   - `platform-services/backend/` - Microservices

3. **Start Developing:**
   - Make code changes
   - Skaffold will automatically rebuild and redeploy
   - Check logs: `kubectl logs -f deployment/<service-name>`

---

## Summary

✅ **Prerequisites installed** (Docker, Minikube, Skaffold, Node.js, Python)  
✅ **Docker configured** (Docker Engine in WSL2)  
✅ **Minikube running** (Kubernetes cluster ready)  
✅ **Environment configured** (.env files set up)  
✅ **All services built** (Docker images created)  
✅ **Application running** (All services deployed)  
✅ **Verified** (Health checks passing, frontend accessible)

**You're all set! 🎉**

For detailed information on specific services or development workflows, see the team-specific onboarding guides in [docs/](docs/).

