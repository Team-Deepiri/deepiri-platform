# 🚀 run_dev.py - Full Stack Development Guide

## Quick Start

Run the entire development stack (all services) with K8s config automatically loaded:

```bash
# From project root
python run_dev.py
```

That's it! 🎉

---

## What It Does

1. **Loads ALL k8s ConfigMaps** from `ops/k8s/configmaps/*.yaml`
2. **Loads ALL k8s Secrets** from `ops/k8s/secrets/*.yaml`
3. **Injects 126+ environment variables** into the environment
4. **Starts all services** from `docker-compose.dev.yml`

**No `.env` files needed!** Just like professional K8s workflow.

---

## Services Started

### 🌐 Frontend & UI
- **Frontend:** http://localhost:5173
- **Cyrex Interface:** http://localhost:5175

### 🔧 Backend Microservices
- **API Gateway:** http://localhost:5100
- **Auth Service:** http://localhost:5001
- **Task Orchestrator:** http://localhost:5002
- **Engagement Service:** http://localhost:5003
- **Platform Analytics:** http://localhost:5004
- **Notification Service:** http://localhost:5005
- **External Bridge:** http://localhost:5006
- **Challenge Service:** http://localhost:5007
- **Realtime Gateway:** http://localhost:5008

### 🤖 AI/ML Services
- **Cyrex API:** http://localhost:8000
- **MLflow:** http://localhost:5500
- **Jupyter Notebook:** http://localhost:8888

### 💾 Infrastructure
- **PostgreSQL:** postgresql://localhost:5432
- **pgAdmin:** http://localhost:5050
- **Adminer:** http://localhost:8080 (lightweight viewer)
- **Redis:** redis://localhost:6380
- **InfluxDB:** http://localhost:8086
- **MinIO Console:** http://localhost:9001
- **Milvus:** localhost:19530

---

## Prerequisites

### One-Time Setup

```bash
# 1. Install Python dependency
pip install pyyaml

# 2. Create secrets file (see ops/k8s/secrets/README.md for template)
touch ops/k8s/secrets/secrets.yaml

# 3. (Optional) Add your secrets to secrets.yaml
# For local dev, you can start with an empty file or use defaults from README
```

---

## Common Commands

```bash
# Start all services
python run_dev.py

# View logs (all services)
docker compose -f docker-compose.dev.yml logs -f

# View logs (specific service)
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f auth-service

# Stop all services
docker compose -f docker-compose.dev.yml down

# Stop and remove volumes (clean slate)
docker compose -f docker-compose.dev.yml down -v

# Restart specific service
docker compose -f docker-compose.dev.yml restart api-gateway
```

---

## Example Output

```bash
$ python run_dev.py

🚀 Starting Development Environment (All Services)...
   (Loading k8s ConfigMaps & Secrets from ops/k8s/)

   ✓ Loaded 11 vars from api-gateway-configmap.yaml
   ✓ Loaded 6 vars from auth-service-configmap.yaml
   ✓ Loaded 4 vars from challenge-service-configmap.yaml
   ✓ Loaded 43 vars from configmap.yaml
   ✓ Loaded 16 vars from cyrex-configmap.yaml
   ... (loading all configmaps and secrets)
   ✓ Loaded 37 vars from secrets.yaml

📦 Loaded 126 environment variables

✅ Development Environment Started!

Access your services:
  - Frontend:        http://localhost:5173
  - API Gateway:     http://localhost:5100
  - Cyrex API:       http://localhost:8000
  ... (all services)
```

---

## vs Team-Specific Scripts

| Script | Services | Use Case |
|--------|----------|----------|
| **`python run_dev.py`** | **ALL services** | Full stack development, integration testing |
| `cd team_dev_environments/backend-team && python run.py` | Backend only | Backend team development |
| `cd team_dev_environments/ai-team && python run.py` | AI/ML only | AI team development |
| `cd team_dev_environments/frontend-team && python run.py` | Frontend only | Frontend team development |

**Use `run_dev.py` when:**
- ✅ You need the full stack
- ✅ You're doing integration testing
- ✅ You're a platform engineer
- ✅ You're starting fresh and want everything

**Use team scripts when:**
- ✅ You only need specific services
- ✅ You want faster startup
- ✅ You're focused on one area

---

## Configuration

### Edit K8s Config

```bash
# Edit public configuration
vim ops/k8s/configmaps/auth-service-configmap.yaml

# Edit secrets
vim ops/k8s/secrets/secrets.yaml

# Restart services to pick up changes
docker compose -f docker-compose.dev.yml restart auth-service
```

### Single Source of Truth

All configuration comes from:
- `ops/k8s/configmaps/*.yaml` - Public config
- `ops/k8s/secrets/secrets.yaml` - Secrets

**No `.env` files to manage!**

---

## Troubleshooting

### "docker: command not found"

Make sure Docker is installed and in your PATH:
```bash
docker --version
```

### Services not starting

Check Docker is running:
```bash
docker ps
```

Check logs for errors:
```bash
docker compose -f docker-compose.dev.yml logs
```

### Port conflicts

If ports are already in use, stop conflicting services:
```bash
# Check what's using port 5173 (for example)
netstat -ano | findstr :5173        # Windows
lsof -i :5173                       # Linux/Mac
```

### Out of memory

Some services (especially AI/ML) need resources. Increase Docker memory:
- **Docker Desktop:** Settings → Resources → Memory (8GB+ recommended)

---

## Benefits of This Approach

✅ **No `.env` files** - All config in k8s YAML format  
✅ **Professional workflow** - Mimics production Kubernetes  
✅ **Single source of truth** - `ops/k8s/` directory  
✅ **No drift** - Local dev matches production  
✅ **Easy updates** - Edit YAML, restart service  
✅ **Team ready** - Same config for everyone  

---

**This is how enterprise microservices teams work!** 🚀

