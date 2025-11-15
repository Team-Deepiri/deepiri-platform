# Getting Started with Deepiri

Complete guide for setting up Deepiri locally for development. This covers both **local services** (running directly) and **local Kubernetes** (Minikube/Kind/k3d) setups.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Service Setup](#service-setup)
5. [Kubernetes Setup (Local Dev)](#kubernetes-setup-local-dev)
6. [Troubleshooting](#troubleshooting)
7. [Next Steps](#next-steps)

---

## Quick Start

### Option 1: Docker Compose (Easiest) ⚡

```bash
# Navigate to project root
cd deepiri

# Copy environment file
cp env.example .env

# Edit .env - Set AI_PROVIDER=localai for free local AI
# For LocalAI, you can leave OPENAI_API_KEY empty

# Start all services
docker-compose -f docker-compose.dev.yml up -d

# Check services
docker-compose -f docker-compose.dev.yml ps
```

**Services Available:**
- Frontend: http://localhost:5173
- Backend API: http://localhost:5000
- Python Agent: http://localhost:8000
- MongoDB: localhost:27017
- Redis: localhost:6379

### Option 2: Local Services (No Docker)

```bash
# 1. Start MongoDB
# macOS
brew services start mongodb-community
# Linux
sudo systemctl start mongodb
# Windows: Start MongoDB service from Services panel

# 2. Start Redis
# macOS
brew services start redis
# Linux
sudo systemctl start redis-server
# Windows: Start Redis service

# 3. Start LocalAI (Optional - for free local AI)
docker run -d --name local-ai -p 8080:8080 localai/localai:latest

# 4. Start Python Agent
cd python_backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp env.example.python_backend .env
# Edit .env: Set AI_PROVIDER=localai, LOCALAI_API_BASE=http://localhost:8080/v1
uvicorn app.main:app --reload --port 8000

# 5. Start Node Backend
cd api-server
npm install
cp env.example.api-server .env
# Edit .env: Set AI_PROVIDER=localai, LOCALAI_API_BASE=http://localhost:8080/v1
npm start

# 6. Start Frontend
cd frontend
npm install
cp env.example.frontend .env.local
# Edit .env.local: VITE_API_URL=http://localhost:5000/api
npm run dev
```

### Option 3: Local Kubernetes (Minikube/Kind/k3d)

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
kubectl apply -f configmap.yaml

# Create Secrets (sensitive data - edit secrets/secrets.yaml first!)
kubectl apply -f secrets/secrets.yaml

# Deploy services
kubectl apply -f mongodb-deployment.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f localai-deployment.yaml
kubectl apply -f pyagent-deployment.yaml
kubectl apply -f backend-deployment.yaml

# 3. Check services
kubectl get pods
kubectl get services

# 4. Port forward to access services locally
kubectl port-forward svc/backend-service 5000:5000
kubectl port-forward svc/pyagent-service 8000:8000
```

**Note:** For local Kubernetes, you don't need `.env` files. Everything is configured via ConfigMaps and Secrets.

---

## Prerequisites

### Required Software

- **Node.js** 18.x or higher
- **Python** 3.10 or higher
- **Docker** and **Docker Compose** (for Docker/Kubernetes options)
- **Git**
- **MongoDB** 6.0+ (or use Docker)
- **Redis** 7.0+ (or use Docker)

### Optional but Recommended

- **kubectl** (for Kubernetes option)
- **Minikube**, **Kind**, or **k3d** (for local Kubernetes)
- **VS Code** or your preferred IDE
- **MongoDB Compass** (for database management)

### System Requirements

- **RAM:** Minimum 8GB, Recommended 16GB+
- **Storage:** Minimum 20GB free space
- **OS:** Windows 10+, macOS 10.15+, or Linux (Ubuntu 20.04+)

---

## Architecture Overview

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

### Service Ports Reference

| Service | Local URL | Docker Service | K8s Service | Required? |
|---------|-----------|----------------|-------------|-----------|
| **Frontend** | http://localhost:5173 | N/A | Port-forward | ✅ Yes |
| **Backend** | http://localhost:5000 | backend:5000 | backend-service:5000 | ✅ Yes |
| **Python Agent** | http://localhost:8000 | pyagent:8000 | pyagent-service:8000 | ✅ Yes |
| **MongoDB** | localhost:27017 | mongodb:27017 | mongodb-service:27017 | ✅ Yes |
| **Redis** | localhost:6379 | redis:6379 | redis-service:6379 | ✅ Yes |
| **LocalAI/Ollama** | http://localhost:8080 | localai:8080 | localai-service:8080 | ✅ Yes (for free AI) |
| **ChromaDB** | Embedded in PyAgent | Embedded | Embedded | ✅ Yes (for RAG) |
| **Firebase Auth** | N/A | N/A | N/A | ⚠️ Optional (can skip) |
| **Prometheus/Grafana** | localhost:9090/3001 | prometheus:9090 | Optional | ⚠️ Optional |

---

## Service Setup

### 1. AI / LLM Service (Local/Free Path)

**Option A: LocalAI (Recommended)**
```bash
# Using Docker
docker run -d --name local-ai -p 8080:8080 localai/localai:latest

# Or using LocalAI binary
curl https://localai.io/install.sh | sh
local-ai serve
```

**Option B: Ollama**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama3.2:1b

# Set in .env
AI_PROVIDER=ollama
OLLAMA_API_BASE=http://localhost:11434
```

**Option C: LM Studio**
- Download LM Studio
- Start local server on port 1234
- Set `AI_PROVIDER=openai` and `OPENAI_API_BASE=http://localhost:1234/v1`

### 2. Databases

**MongoDB:**
```bash
# Docker
docker run -d --name mongodb -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  mongo:7.0

# Or local installation
# macOS: brew install mongodb-community
# Linux: sudo apt-get install mongodb
# Windows: Download from mongodb.com
```

**Redis:**
```bash
# Docker
docker run -d --name redis -p 6379:6379 redis:7-alpine

# Or local installation
# macOS: brew install redis
# Linux: sudo apt-get install redis-server
# Windows: Download from redis.io
```

### 3. Python Agent

```bash
cd python_backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy and configure env
cp env.example.python_backend .env
# Edit .env: Set AI_PROVIDER=localai

# Start server
uvicorn app.main:app --reload --port 8000
```

### 4. Node.js Backend

```bash
cd api-server

# Install dependencies
npm install

# Copy and configure env
cp env.example.api-server .env
# Edit .env: Set AI_PROVIDER=localai

# Start server
npm start
```

### 5. Frontend

```bash
cd frontend

# Install dependencies
npm install

# Copy and configure env
cp env.example.frontend .env.local
# Edit .env.local: VITE_API_URL=http://localhost:5000/api

# Start dev server
npm run dev
```

---

## Kubernetes Setup (Local Dev)

### Prerequisites

Choose one:
- **Minikube**: `minikube start`
- **Kind**: `kind create cluster --name deepiri`
- **k3d**: `k3d cluster create deepiri`

### Configuration

Kubernetes uses **ConfigMaps** and **Secrets** instead of `.env` files:

**ConfigMap** (`ops/k8s/configmap.yaml`):
- Non-sensitive configuration
- Ports, feature flags, URLs
- Already configured for local dev

**Secrets** (`ops/k8s/secrets/secrets.yaml`):
- Sensitive data (passwords, API keys)
- **Edit this file** with your local dev values
- Use `kubectl apply -f secrets/secrets.yaml` to deploy

### Deployment Steps

```bash
# 1. Start Kubernetes cluster
minikube start  # or kind/k3d

# 2. Apply ConfigMap
kubectl apply -f ops/k8s/configmap.yaml

# 3. Edit and apply Secrets
# Edit ops/k8s/secrets/secrets.yaml with your local values
kubectl apply -f ops/k8s/secrets/secrets.yaml

# 4. Deploy services (order matters)
kubectl apply -f ops/k8s/mongodb-deployment.yaml
kubectl apply -f ops/k8s/redis-deployment.yaml
kubectl apply -f ops/k8s/localai-deployment.yaml
kubectl apply -f ops/k8s/pyagent-deployment.yaml
kubectl apply -f ops/k8s/backend-deployment.yaml

# 5. Check status
kubectl get pods
kubectl get services

# 6. Port forward to access locally
kubectl port-forward svc/backend-service 5000:5000 &
kubectl port-forward svc/pyagent-service 8000:8000 &
kubectl port-forward svc/localai-service 8080:8080 &
```

### Service URLs in Kubernetes

In Kubernetes, services communicate using service names:
- `mongodb-service:27017` (not `localhost:27017`)
- `redis-service:6379` (not `localhost:6379`)
- `backend-service:5000` (not `localhost:5000`)
- `pyagent-service:8000` (not `localhost:8000`)
- `localai-service:8080` (not `localhost:8080`)

The ConfigMap and Deployments are already configured with these service names.

---

## Troubleshooting

### Port Already in Use

```bash
# Find process using port
# Windows
netstat -ano | findstr :5000
taskkill /PID <pid> /F

# macOS/Linux
lsof -i :5000
kill -9 <pid>
```

### MongoDB Connection Issues

```bash
# Check MongoDB is running
# Docker
docker ps | grep mongodb

# Local
# macOS
brew services list | grep mongodb
# Linux
sudo systemctl status mongodb

# Test connection
mongosh mongodb://admin:password@localhost:27017/deepiri?authSource=admin
```

### LocalAI Not Responding

```bash
# Check LocalAI is running
curl http://localhost:8080/v1/models

# Check logs
docker logs local-ai

# Restart LocalAI
docker restart local-ai
```

### Python Agent Issues

```bash
# Check virtual environment is activated
which python  # Should show venv path

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall

# Check logs
# Look for errors in terminal where uvicorn is running
```

### Frontend Can't Connect to Backend

1. Check backend is running: `curl http://localhost:5000/health`
2. Check frontend `.env.local`: `VITE_API_URL=http://localhost:5000/api`
3. Check browser console for CORS errors
4. Restart frontend dev server

### Kubernetes Pods Not Starting

```bash
# Check pod status
kubectl get pods

# Check pod logs
kubectl logs <pod-name>

# Check pod events
kubectl describe pod <pod-name>

# Check ConfigMap/Secrets are applied
kubectl get configmap deepiri-config
kubectl get secret deepiri-secrets
```

### Docker Issues

```bash
# Reset Docker containers
docker-compose down -v
docker-compose up -d

# View logs
docker-compose logs -f <service-name>

# Rebuild images
docker-compose build --no-cache
```

---

## Next Steps

1. **Configure Environment**: See `ENVIRONMENT_VARIABLES.md` for detailed environment variable reference
2. **Start Services**: Follow Quick Start section above
3. **Verify Setup**: Check all services are running
4. **Test Frontend**: Open http://localhost:5173
5. **Read Documentation**: 
   - `ENVIRONMENT_VARIABLES.md` - Detailed environment configuration
   - `START_EVERYTHING.md` - Service startup guide
   - `FIND_YOUR_TASKS.md` - Development tasks

---

## Important Notes

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

---

**Last Updated:** 2024  
**Maintained by:** Platform Team

