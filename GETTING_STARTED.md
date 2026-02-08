# Getting Started with Deepiri

**Welcome to Deepiri!** This is your central navigation hub. Find your role below and follow the links to your specific setup guide.

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

## 🚀 **START HERE: Complete Setup Guide**

**⭐ NEW USERS: Begin with the complete setup guide for building and running the entire project:**

👉 **[COMPLETE_SETUP.md](COMPLETE_SETUP.md)** - **Complete step-by-step guide for setting up and running all services**

This guide covers:
- ✅ All prerequisites and dependencies
- ✅ Complete environment setup
- ✅ Building all services
- ✅ Running the entire stack
- ✅ Verification and testing

**After completing the setup guide, return here for team-specific information.**

---

## 🎯 Quick Navigation by Role

### **New to the Project? Start Here:**

1. **⭐ Complete Setup** → [COMPLETE_SETUP.md](COMPLETE_SETUP.md) - **Build and run the entire project**
2. **Find Your Role** → [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)
3. **Read Your Team's Onboarding Guide** (see links below)
4. **Choose Your Development Environment** (⭐ **PRIMARY: Skaffold** or Docker Compose)
5. **Set Up Your Environment** (follow your team's guide)

---

## 👥 Team-Specific Onboarding Guides

### **AI Team**
- **Onboarding Guide:** [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md)
- **AI Services Overview:** [docs/AI_SERVICES_OVERVIEW.md](docs/AI_SERVICES_OVERVIEW.md)

### **ML Team**
- **ML Engineer Guide:** [docs/ML_ENGINEER_COMPLETE_GUIDE.md](docs/ML_ENGINEER_COMPLETE_GUIDE.md)
- **MLOps Guide:** [docs/MLOPS_TEAM_ONBOARDING.md](docs/MLOPS_TEAM_ONBOARDING.md)

### **Backend Team**
- **Onboarding Guide:** [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md)
- **Microservices Setup:** [docs/MICROSERVICES_SETUP.md](docs/MICROSERVICES_SETUP.md)
- **Your Code:** 
  - `deepiri-core-api/` (Main API)
  - `platform-services/backend/` (Microservices)

### **Frontend Team**
- **Onboarding Guide:** [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)
- **Your Code:** `deepiri-web-frontend/` (React + Vite)

### **Infrastructure Team + Platform Engineers**
- **Onboarding Guide:** [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)
- **Kubernetes Setup:** [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md) ⭐ **PRIMARY: Skaffold for K8s Development**
- **Quick Skaffold Guide:** [SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)
- **Your Code:** 
  - `ops/k8s/` (Kubernetes manifests)
  - `scripts/` (Infrastructure scripts)
  - `skaffold.yaml` (Skaffold configuration)

### **QA Team**
- **Onboarding Guide:** [docs/SECURITY_QA_TEAM_ONBOARDING.md](docs/SECURITY_QA_TEAM_ONBOARDING.md)

---

## 🚀 Quick Start Options

**⭐ PRIMARY RECOMMENDATION: Use Skaffold for Kubernetes development (Option 1)**

### **Prerequisites: Install Docker First**

**For WSL2 users (Recommended):**
```bash
# Install Docker Engine (not Docker Desktop - more reliable in WSL2)
cd deepiri
./scripts/setup-docker-wsl2.sh

# After installation, restart WSL2:
# In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify Docker is working
docker --version
docker ps
```

**What the script does:**
- Installs Docker Engine, Buildx, and Compose (official Docker packages)
- Verifies Docker's official GPG key fingerprint (security check)
- Configures WSL2 for systemd
- See [QUICK-START-SCRIPTS.md](QUICK-START-SCRIPTS.md) for manual installation steps

**Why Docker Engine instead of Docker Desktop?**
- More reliable WSL2 integration (no socket connection issues)
- Better performance in WSL2
- Full control over Docker daemon

---

Choose the development environment that works best for you:

### **Option 1: Kubernetes with Skaffold (PRIMARY - Recommended)** ☸️ ⭐

**Best for:** All teams - production-like local development with smart rebuilds and file sync

**Skaffold provides smart rebuilds, file sync, and automatic port-forwarding:**

```bash
# 1. Setup Minikube (first time only)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# Or use the setup script
./scripts/setup-minikube-wsl2.sh      # Linux/WSL2
.\scripts\setup-minikube-wsl2.ps1     # Windows PowerShell

# 2. Start with Skaffold (handles everything automatically)
skaffold dev --port-forward

# Or use the helper script
./scripts/start-skaffold-dev.sh        # Linux/WSL2
.\scripts\start-skaffold-dev.ps1      # Windows PowerShell
```

**Skaffold automatically:**
- ✅ Builds Docker images using Minikube's Docker daemon
- ✅ Deploys to Kubernetes
- ✅ Auto-syncs files for instant updates (no rebuilds needed for `.ts`, `.js`, `.py` files)
- ✅ Port-forwards all services automatically
- ✅ Streams logs from all services
- ✅ Cleans up on exit (Ctrl+C)

**Stop Skaffold:**
```bash
# Press Ctrl+C in Skaffold terminal (auto-cleanup)
# Or manually cleanup:
./scripts/stop-skaffold.sh             # Linux/WSL2
.\scripts\stop-skaffold.ps1            # Windows PowerShell
```

**📚 More Details:**
- **Quick Start:** [SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)
- **Complete Guide:** [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md)
- **Configuration:** `skaffold.yaml`

---

### **Option 2: Docker Compose (Alternative - Simpler but less production-like)** 🐳

**Best for:** Quick local testing, teams not using Kubernetes

```bash
# Navigate to project root
cd deepiri

# Copy environment file
cp env.example .env
# Edit .env - Set AI_PROVIDER=localai for free local AI

# Normal start (uses existing images - no rebuild)
docker compose -f docker-compose.dev.yml up -d

# To rebuild (only when code changes or you want fresh images)
./rebuild.sh              # Linux/Mac (removes old images, rebuilds fresh)
.\rebuild.ps1             # Windows PowerShell

# Check services
docker compose -f docker-compose.dev.yml ps
```

**💡 Normal `docker compose up` does NOT rebuild** - it uses existing images. Only use `rebuild.sh` / `rebuild.ps1` when you need to rebuild after code changes.

**Services Available:**
- Frontend: http://localhost:5173
- Backend API: http://localhost:5000
- Python Agent: http://localhost:8000
- MongoDB: localhost:27017
- Redis: localhost:6379

**📚 More Details:**
- **Complete Setup Guide:** [START_EVERYTHING.md](START_EVERYTHING.md)
- **Environment Variables:** [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)
- **Troubleshooting:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

### **Option 3: Local Services (No Docker - Advanced)**

**Best for:** Developers who prefer running services directly on their machine

```bash
# 1. Start MongoDB
# macOS: brew services start mongodb-community
# Linux: sudo systemctl start mongodb
# Windows: Start MongoDB service from Services panel

# 2. Start Redis
# macOS: brew services start redis
# Linux: sudo systemctl start redis-server
# Windows: Start Redis service

# 3. Start LocalAI (Optional - for free local AI)
docker run -d --name local-ai -p 8080:8080 localai/localai:latest

# 4. Start Python Agent
cd diri-cyrex
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp env.example.diri-cyrex .env
# Edit .env: Set AI_PROVIDER=localai, LOCALAI_API_BASE=http://localhost:8080/v1
uvicorn app.main:app --reload --port 8000

# 5. Start Node Backend
cd deepiri-core-api
npm install
cp env.example.deepiri-core-api .env
# Edit .env: Set AI_PROVIDER=localai, LOCALAI_API_BASE=http://localhost:8080/v1
npm start

# 6. Start Frontend
cd deepiri-web-frontend
npm install
cp env.example.deepiri-web-frontend .env.local
# Edit .env.local: VITE_API_URL=http://localhost:5000/api
npm run dev
```

**📚 More Details:**
- **Environment Setup:** [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)
- **Environment Variables:** [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)

---

### **Option 4: Manual Kubernetes (Advanced - Not Recommended)**

**Best for:** Platform engineers who need full control over Kubernetes deployment

```bash
# 1. Start local Kubernetes cluster
# Option A: Minikube
minikube start

# Option B: Kind
kind create cluster --name deepiri

# Option C: k3d
k3d cluster create deepiri

# 2. Apply Kubernetes manifests
cd deepiri/ops/k8s

# Create ConfigMap (non-sensitive config)
kubectl apply -f configmaps/configmap.yaml

# Create Secrets (sensitive data - edit secrets/secrets.yaml first!)
kubectl apply -f secrets/secrets.yaml

# Deploy services
kubectl apply -f mongodb-deployment.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f localai-deployment.yaml
kubectl apply -f cyrex-deployment.yaml
kubectl apply -f backend-deployment.yaml

# 3. Check services
kubectl get pods
kubectl get services

# 4. Port forward to access services locally
kubectl port-forward svc/backend-service 5000:5000
kubectl port-forward svc/cyrex-service 8000:8000
```

**Note:** For local Kubernetes, you don't need `.env` files. Everything is configured via ConfigMaps and Secrets.

**📚 More Details:**
- **Platform Team Guide:** [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)
- **Kubernetes Manifests:** `ops/k8s/`

---

## 📋 Prerequisites

### Required Software

- **Node.js** 18.x or higher
- **Python** 3.10 or higher
- **Docker** and **Docker Compose** (for Docker/Kubernetes options)
- **Git**

### Required for Primary Method (Skaffold)

- **kubectl** (required for Skaffold)
- **Minikube** (required for local Kubernetes)
- **Skaffold** (required - primary development method)

### Optional but Recommended

- **VS Code** or your preferred IDE
- **MongoDB Compass** (for database management)
- **Docker Compose** (for alternative method)

### System Requirements

- **RAM:** Minimum 8GB, Recommended 16GB+
- **Storage:** Minimum 20GB free space
- **OS:** Windows 10+, macOS 10.15+, or Linux (Ubuntu 20.04+)

---

## 📚 Essential Documentation

### **Getting Started**
- **[FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)** - Find your role and responsibilities
- **[START_EVERYTHING.md](START_EVERYTHING.md)** - Detailed service startup guide
- **[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)** - Complete environment setup
- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - Environment variable reference

### **Development Tools (PRIMARY METHOD)**
- **[SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)** - Quick Skaffold + Kubernetes guide ⭐ **PRIMARY**
- **[docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md)** - Complete Skaffold documentation ⭐ **PRIMARY**
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[docs/DOCKER-IMAGE-CLEANSING-COMMANDS.md](docs/DOCKER-IMAGE-CLEANSING-COMMANDS.md)** - Docker cleanup guide (alternative method)

### **Architecture & System**
- **[docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md)** - System design overview
- **[docs/MICROSERVICES_ARCHITECTURE.md](docs/MICROSERVICES_ARCHITECTURE.md)** - Microservices details
- **[docs/MICROSERVICES_SETUP.md](docs/MICROSERVICES_SETUP.md)** - Microservices setup guide
- **[DOCUMENTATION-INDEX.md](DOCUMENTATION-INDEX.md)** - Complete index of all documentation

### **Team-Specific Documentation**
- **AI Team:** [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md), [docs/ML_ENGINEER_COMPLETE_GUIDE.md](docs/ML_ENGINEER_COMPLETE_GUIDE.md)
- **Backend Team:** [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md), [docs/MICROSERVICES_SETUP.md](docs/MICROSERVICES_SETUP.md)
- **Frontend Team:** [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)
- **Platform Team:** [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md), [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md)
- **Security/QA Team:** [docs/SECURITY_QA_TEAM_ONBOARDING.md](docs/SECURITY_QA_TEAM_ONBOARDING.md)

---

## 🏗️ Architecture Overview

### Service Ports Reference

| Service | Local URL | Docker Service | K8s Service | Required? |
|---------|-----------|----------------|-------------|-----------|
| **Frontend** | http://localhost:5173 | N/A | Port-forward | ✅ Yes |
| **Backend** | http://localhost:5000 | backend:5000 | backend-service:5000 | ✅ Yes |
| **Python Agent** | http://localhost:8000 | cyrex:8000 | cyrex-service:8000 | ✅ Yes |
| **MongoDB** | localhost:27017 | mongodb:27017 | mongodb-service:27017 | ✅ Yes |
| **Redis** | localhost:6379 | redis:6379 | redis-service:6379 | ✅ Yes |
| **LocalAI/Ollama** | http://localhost:8080 | localai:8080 | localai-service:8080 | ✅ Yes (for free AI) |
| **ChromaDB** | Embedded in Cyrex | Embedded | Embedded | ✅ Yes (for RAG) |
| **Firebase Auth** | N/A | N/A | N/A | ⚠️ Optional (can skip) |
| **Prometheus/Grafana** | localhost:9090/3001 | prometheus:9090 | Optional | ⚠️ Optional |

### Local Development Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (Vite)                          │
│                    http://localhost:5173                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ HTTP
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Node.js Backend (Express)                      │
│              http://localhost:5000                          │
│              - User Service                                 │
│              - Task Service                                 │
│              - Challenge Service                            │
│              - Gamification Service                         │
└───────┬───────────────────────────────┬───────────────────────┘
        │                               │
        │ HTTP                          │ HTTP
        ▼                               ▼
┌───────────────┐              ┌──────────────────┐
│   MongoDB     │              │  Python Agent    │
│  localhost:   │              │  localhost:8000  │
│   27017       │              │  - AI/LLM        │
└───────────────┘              │  - RAG/Embeddings│
                               │  - ChromaDB      │
┌───────────────┐              └────────┬─────────┘
│    Redis      │                        │
│  localhost:   │                        │ HTTP
│   6379        │                        ▼
└───────────────┘              ┌──────────────────┐
                                │   LocalAI/Ollama │
                                │  localhost:8080  │
                                │  (Local LLM)     │
                                └──────────────────┘
```

---

## 🛠️ Quick Reference: Build, Run, Stop, Logs

> **⭐ PRIMARY METHOD: Use Skaffold (see below). Docker Compose is available as an alternative.**

### ☸️ Kubernetes with Skaffold (PRIMARY) ⭐

#### **How to Build**

```bash
# Setup Minikube (first time only)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# Or use setup script
./scripts/setup-minikube-wsl2.sh      # Linux/WSL2
.\scripts\setup-minikube-wsl2.ps1     # Windows PowerShell

# Build images (Skaffold handles this automatically)
skaffold build

# Build specific image
skaffold build --artifact=deepiri-core-api
skaffold build --artifact=deepiri-cyrex
```

**💡 Tip:** Skaffold automatically rebuilds when files change in dev mode!

#### **How to Run**

```bash
# Using helper script (recommended - uses skaffold-local.yaml)
./scripts/start-skaffold-dev.sh        # Linux/WSL2
.\scripts\start-skaffold-dev.ps1      # Windows PowerShell

# Or directly
skaffold dev -f skaffold-local.yaml --port-forward

# Run once (no watch mode)
skaffold run -f skaffold-local.yaml --port-forward
```

**Skaffold automatically:**
- ✅ Builds Docker images
- ✅ Deploys to Kubernetes
- ✅ Port-forwards services
- ✅ Streams logs
- ✅ Auto-syncs files (no rebuilds needed for `.ts`, `.js`, `.py`)

**Services Available (auto port-forwarded):**
- Backend: http://localhost:5000
- Cyrex: http://localhost:8000
- MongoDB: localhost:27017
- Redis: localhost:6379
- LocalAI: http://localhost:8080

#### **How to Stop**

```bash
# Press Ctrl+C in Skaffold terminal (auto-cleanup)

# Or manually cleanup:
./scripts/stop-skaffold.sh             # Linux/WSL2
.\scripts\stop-skaffold.ps1            # Windows PowerShell

# Or use Skaffold directly
skaffold delete
```

#### **How to Check Logs**

```bash
# Skaffold streams logs automatically in dev mode
# Or view logs manually:

# All pods
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

---

### 🐳 Docker Compose (Alternative)

#### **How to Build**

```bash
# Full rebuild (removes old images, rebuilds fresh)
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows PowerShell

# Rebuild specific service
docker compose -f docker-compose.dev.yml build --no-cache <service-name>

# Rebuild all services (without removing old images)
docker compose -f docker-compose.dev.yml build
```

**💡 Tip:** Normal `docker compose up` does NOT rebuild - it uses existing images. Only rebuild when code changes!

#### **How to Run**

```bash
# Start all services (uses existing images - fast!)
docker compose -f docker-compose.dev.yml up -d

# Start specific service
docker compose -f docker-compose.dev.yml up -d <service-name>

# Start and view logs in terminal
docker compose -f docker-compose.dev.yml up
```

**Services Available:**
- Frontend: http://localhost:5173
- Backend API: http://localhost:5000
- Python Agent: http://localhost:8000
- MongoDB: localhost:27017
- Redis: localhost:6379

#### **How to Stop**

```bash
# Stop all services (keeps containers)
docker compose -f docker-compose.dev.yml stop

# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Stop and remove containers + volumes (WARNING: Deletes data!)
docker compose -f docker-compose.dev.yml down -v
```

#### **How to Check Logs**

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

---

### 🔧 Additional Useful Commands

#### **Check Service Status**

**Docker Compose:**
```bash
docker compose -f docker-compose.dev.yml ps
docker stats                          # Resource usage
```

**Kubernetes:**
```bash
kubectl get pods                      # Pod status
kubectl get services                  # Service status
kubectl get deployments               # Deployment status
kubectl describe pod <pod-name>       # Detailed pod info
```

#### **Restart Services**

**Docker Compose:**
```bash
docker compose -f docker-compose.dev.yml restart
docker compose -f docker-compose.dev.yml restart <service-name>
```

**Kubernetes:**
```bash
kubectl rollout restart deployment/deepiri-core-api
kubectl rollout restart deployment/deepiri-cyrex
```

#### **Access Service Shell**

**Docker Compose:**
```bash
docker compose -f docker-compose.dev.yml exec <service-name> sh
docker compose -f docker-compose.dev.yml exec backend sh
docker compose -f docker-compose.dev.yml exec cyrex sh
```

**Kubernetes:**
```bash
kubectl exec -it deployment/deepiri-core-api -- sh
kubectl exec -it deployment/deepiri-cyrex -- sh
```

---

## 🐛 Troubleshooting

### Quick Fixes

**Port Already in Use:**
```bash
# Windows
netstat -ano | findstr :5000
taskkill /PID <pid> /F

# macOS/Linux
lsof -i :5000
kill -9 <pid>
```

**Docker Issues:**
```bash
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d
```

**Kubernetes Pods Not Starting:**
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**📚 More Help:**
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
- **Your Team's Onboarding Guide** - Team-specific troubleshooting

---

## ⚙️ Environment Configuration

### Local vs Cloud Variables

**For Local Development:**
- ✅ Use `DEV_*` variables (e.g., `DEV_CLIENT_URL`, `DEV_API_URL`)
- ✅ Use `localhost` URLs for all services
- ✅ Set `AI_PROVIDER=localai` for free local AI
- ✅ Use `LOCALAI_API_BASE=http://localhost:8080/v1`
- ❌ **DO NOT** set `PROD_*` variables locally
- ❌ **DO NOT** use cloud database URLs locally

**For Cloud/Production:**
- `PROD_*` variables are **ONLY** for reference when creating Kubernetes Secrets
- Cloud deployments use ConfigMaps/Secrets, not `.env` files
- Production values go in Kubernetes Secrets, not local `.env` files

### Cost Breakdown

**Local Development (Free Path):**

| Component | Cost | Notes |
|-----------|------|-------|
| **LocalAI/Ollama** | $0 | Runs locally, no API costs |
| **MongoDB** | $0 | Local instance or Docker |
| **Redis** | $0 | Local instance or Docker |
| **ChromaDB** | $0 | Embedded, runs in Python Agent |
| **Node.js Backend** | $0 | Runs locally |
| **Python Agent** | $0 | Runs locally |
| **Frontend** | $0 | Vite dev server |
| **Total** | **$0/month** | Everything runs locally |

**Optional Services (Can Skip for Local Dev):**
- Firebase Auth: Can skip, use JWT only
- FCM: Can skip, notifications work without
- Prometheus/Grafana: Optional monitoring
- External APIs (Google Maps, Weather): Optional features

**📚 More Details:**
- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - Complete environment variable reference

---

## 🎯 Next Steps

1. **Find Your Role:** [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)
2. **Read Your Team's Onboarding Guide** (see Team-Specific Onboarding Guides above)
3. **Choose Your Development Environment** (⭐ **PRIMARY: Skaffold** or Docker Compose)
4. **Set Up Your Environment** (follow your team's guide)
5. **Start Coding!** 🚀

---

## 📞 Need Help?

- **Troubleshooting:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Your Team's Guide:** See Team-Specific Onboarding Guides above
- **Documentation Index:** [DOCUMENTATION-INDEX.md](DOCUMENTATION-INDEX.md)

---

**Last Updated:** 2024  
**Maintained by:** Platform Team
