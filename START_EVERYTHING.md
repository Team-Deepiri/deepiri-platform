# Start Everything - Complete Testing Guide

This guide will help you start **ALL** services for comprehensive testing.

## Prerequisites Check

```bash
# Check Docker is running
docker --version
docker-compose --version

# Check Node.js (for frontend)
node --version  # Should be 18.x or higher

# Check Python (for AI service)
python --version  # Should be 3.11 or higher
```

## Quick Setup (First Time)

**IMPORTANT**: Before starting services, run the dependency fix script:

```bash
# Make script executable (Linux/Mac)
chmod +x scripts/fix-dependencies.sh

# Install all dependencies
bash scripts/fix-dependencies.sh
```

This will:
- ✅ Install all Node.js dependencies for all services
- ✅ Install Python dependencies
- ✅ Verify logger utilities exist
- ✅ Ensure all required packages are available

**Note**: If you encounter any issues, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for solutions.

## Step 1: Environment Setup

```bash
# Navigate to project root
cd Deepiri/deepiri

# Copy environment files
cp env.example .env
# For Docker deployments, use the same env.example file
# The file supports both local and Docker configurations

# Edit .env file with your API keys
# Required keys:
# - OPENAI_API_KEY (or ANTHROPIC_API_KEY)
# - HUGGINGFACE_API_KEY (optional)
# - FIREBASE_API_KEY (optional)
# - GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET (optional)
# - NOTION_CLIENT_ID, NOTION_CLIENT_SECRET (optional)
```

## Step 2: Choose Your Deployment Method

### ⭐ Option A: Kubernetes with Skaffold (PRIMARY - Recommended) ☸️

**This is the RECOMMENDED way to start everything for production-like development:**

```bash
# 1. Setup Minikube (first time only)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# Or use the setup script
./scripts/setup-minikube-wsl2.sh      # Linux/WSL2
.\scripts\setup-minikube-wsl2.ps1     # Windows PowerShell

# 2. Start with Skaffold (handles everything automatically)
# Using helper script (recommended - uses skaffold-local.yaml)
./scripts/start-skaffold-dev.sh        # Linux/WSL2
.\scripts\start-skaffold-dev.ps1      # Windows PowerShell

# Or directly
skaffold dev -f skaffold-local.yaml --port-forward
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

**See [SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md), [SKAFFOLD_CONFIGS.md](SKAFFOLD_CONFIGS.md), or [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md) for detailed Skaffold documentation.**

### Option B: Docker Compose (Alternative) 🐳

**Simpler option for quick local testing:**

```bash
# Start all services (uses existing images - fast!)
docker compose -f docker-compose.dev.yml up -d

# Check all services are running
docker compose -f docker-compose.dev.yml ps

# View logs for all services
docker compose -f docker-compose.dev.yml logs -f

# View logs for specific service
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f jupyter
```

**💡 Tip:** Normal `docker compose up` does NOT rebuild images - it uses existing ones. This is fast and efficient for daily use.

### Rebuilding (Only When Needed)

**When to rebuild:** After code changes, or when you want fresh images:

```bash
# Use the rebuild script (removes old images, rebuilds fresh)
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows PowerShell

# This automatically:
# 1. Stops containers
# 2. Removes old images (prevents storage bloat!)
# 3. Cleans build cache
# 4. Rebuilds everything fresh
# 5. Starts all services
```

### Common Issues and Fixes

If services fail to start, check:

1. **Missing Dependencies**: Run `bash scripts/fix-dependencies.sh`
2. **Permission Issues**: See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. **Port Conflicts**: Check if ports are already in use
4. **Environment Variables**: Ensure `.env` files are configured
5. **Docker Storage Full**: Run `./rebuild.sh` or `.\rebuild.ps1` to clean old images

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

### Rebuilding Services (Only When Needed)

**Normal operation:** `docker compose up` uses existing images - no rebuild needed.

**When to rebuild:** After code changes, dependency updates, or when you want fresh images:

```bash
# Clean rebuild (removes old images first)
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows PowerShell

# Rebuild cyrex with auto GPU detection (recommended)
# Windows
.\scripts\build-cyrex-auto.ps1

# Linux/Mac
./scripts/build-cyrex-auto.sh

# Or rebuild specific service only
docker compose -f docker-compose.dev.yml build --no-cache cyrex
docker compose -f docker-compose.dev.yml up -d cyrex

# Or manual full rebuild
docker compose -f docker-compose.dev.yml down --rmi local
docker builder prune -af
docker compose -f docker-compose.dev.yml build --no-cache
docker compose -f docker-compose.dev.yml up -d
```

**GPU Detection:** The build system automatically detects your GPU and chooses the best base image (CUDA if GPU ≥4GB, CPU otherwise). This prevents build freezing from large CUDA downloads. See `diri-cyrex/README_BUILD.md` for details.

See [docs/DOCKER-IMAGE-CLEANSING-COMMANDS.md](docs/DOCKER-IMAGE-CLEANSING-COMMANDS.md) for complete rebuild guide.

## Step 3: Verify Services Are Running

```bash
# Test API Gateway (should route to all services)
curl http://localhost:5000/health

# Test individual services
curl http://localhost:5001/health  # User Service
curl http://localhost:5002/health  # Task Service
curl http://localhost:5003/health  # Gamification Service
curl http://localhost:5004/health  # Analytics Service
curl http://localhost:5005/health  # Notification Service
curl http://localhost:5006/health  # Integration Service
curl http://localhost:5007/health  # Challenge Service
curl http://localhost:5008/health  # WebSocket Service

# Test Python AI Service
curl http://localhost:8000/health

# Test databases
curl http://localhost:8081  # Mongo Express (browser)
curl http://localhost:8086  # InfluxDB (browser)
```

## Step 4: Start Frontend (Separate Terminal)

```bash
# Navigate to frontend
cd deepiri-web-frontend

# Install dependencies (first time only)
npm install

# Copy environment file
cp env.example.frontend .env.local

# Edit .env - IMPORTANT: Point to API Gateway
# VITE_API_URL=http://localhost:5000/api
# VITE_CYREX_URL=http://localhost:8000

# Start frontend dev server
npm run dev
```

Frontend will be available at: **http://localhost:5173**

## Step 5: Access All Services

### Web Interfaces

| Service | URL | Description |
|---------|-----|-------------|
| **Frontend** | http://localhost:5173 | Main web application |
| **API Gateway** | http://localhost:5000 | Routes to all microservices |
| **Mongo Express** | http://localhost:8081 | MongoDB admin UI |
| **InfluxDB UI** | http://localhost:8086 | Time-series database UI |
| **MLflow** | http://localhost:5500 | Model tracking (if started) |

### API Endpoints (via API Gateway)

All API calls should go through API Gateway:

```bash
# Users
curl http://localhost:5000/api/users/health

# Tasks
curl http://localhost:5000/api/tasks/health

# Gamification
curl http://localhost:5000/api/gamification/health

# Analytics
curl http://localhost:5000/api/analytics/health

# Challenges
curl http://localhost:5000/api/challenges/health

# Integrations
curl http://localhost:5000/api/integrations/health
```

### Direct Service Ports (for debugging)

| Service | Port | Direct URL |
|---------|------|------------|
| API Gateway | 5000 | http://localhost:5000 |
| User Service | 5001 | http://localhost:5001 |
| Task Service | 5002 | http://localhost:5002 |
| Gamification Service | 5003 | http://localhost:5003 |
| Analytics Service | 5004 | http://localhost:5004 |
| Notification Service | 5005 | http://localhost:5005 |
| Integration Service | 5006 | http://localhost:5006 |
| Challenge Service | 5007 | http://localhost:5007 |
| WebSocket Service | 5008 | http://localhost:5008 |
| Python AI Service | 8000 | http://localhost:8000 |

## Step 6: Monitor Everything

### View All Logs

```bash
# All services
docker-compose -f docker-compose.dev.yml logs -f

# Specific service
docker-compose -f docker-compose.dev.yml logs -f api-gateway
docker-compose -f docker-compose.dev.yml logs -f cyrex
docker-compose -f docker-compose.dev.yml logs -f auth-service
```

### Check Service Status

```bash
# List all running containers
docker-compose -f docker-compose.dev.yml ps

# Check resource usage
docker stats

# Check specific service
docker-compose -f docker-compose.dev.yml ps api-gateway
```

## Quick Commands Reference

### Start Everything
```bash
docker-compose -f docker-compose.dev.yml up -d
cd deepiri-web-frontend && npm run dev
```

### Stop Everything

**⭐ PRIMARY: Kubernetes with Skaffold**
```bash
# Press Ctrl+C in Skaffold terminal (auto-cleanup)
# Or manually:
./scripts/stop-skaffold.sh        # Linux/Mac
.\scripts\stop-skaffold.ps1         # Windows
```

**Alternative: Docker Compose**
```bash
# Stop all services
docker-compose -f docker-compose.dev.yml down

# Stop and remove volumes (WARNING: Deletes data)
docker-compose -f docker-compose.dev.yml down -v
```

### Restart Everything
```bash
docker-compose -f docker-compose.dev.yml restart
```

### Restart Specific Service
```bash
docker-compose -f docker-compose.dev.yml restart api-gateway
docker-compose -f docker-compose.dev.yml restart cyrex
```

### Rebuild Services (after code changes)
```bash
# Rebuild all
docker-compose -f docker-compose.dev.yml build

# Rebuild specific service
docker-compose -f docker-compose.dev.yml build api-gateway

# Rebuild and restart
docker-compose -f docker-compose.dev.yml up -d --build api-gateway
```

## Troubleshooting

### Services Won't Start

```bash
# Check if ports are already in use
# Windows
netstat -ano | findstr :5000
# macOS/Linux
lsof -i :5000

# Kill process using port
# Windows
taskkill /PID <pid> /F
# macOS/Linux
kill -9 <pid>
```

### Database Connection Issues

```bash
# Check MongoDB is running
docker-compose -f docker-compose.dev.yml ps mongodb

# Restart MongoDB
docker-compose -f docker-compose.dev.yml restart mongodb

# Check MongoDB logs
docker-compose -f docker-compose.dev.yml logs mongodb
```

### Frontend Can't Connect to Backend

1. **Check API Gateway is running:**
   ```bash
   curl http://localhost:5000/health
   ```

2. **Check frontend .env file:**
   ```bash
   # Should be:
   VITE_API_URL=http://localhost:5000/api
   ```

3. **Check browser console for CORS errors**

### Python AI Service Issues

```bash
# Check Python service logs
docker-compose -f docker-compose.dev.yml logs cyrex

# Restart Python service
docker-compose -f docker-compose.dev.yml restart cyrex

# Check if API keys are set
docker-compose -f docker-compose.dev.yml exec cyrex env | grep API_KEY
```

## Testing Checklist

Once everything is running, test:

- [ ] Frontend loads at http://localhost:5173
- [ ] API Gateway responds at http://localhost:5000/health
- [ ] All microservices respond to health checks
- [ ] Python AI Service responds at http://localhost:8000/health
- [ ] MongoDB accessible via Mongo Express at http://localhost:8081
- [ ] InfluxDB accessible at http://localhost:8086
- [ ] Frontend can make API calls (check browser network tab)
- [ ] WebSocket connections work (if testing real-time features)

## Next Steps

1. **Read the docs:**
   - `ENVIRONMENT_SETUP.md` - Complete setup guide for new team members
   - `ENVIRONMENT_VARIABLES.md` - Detailed environment variable reference
   - `docs/TROUBLESHOOTING.md` - Comprehensive troubleshooting guide
   - `docs/SHARED_UTILS_ARCHITECTURE.md` - Architecture documentation
   - `GETTING_STARTED.md` - Complete local development setup guide
   - `FIND_YOUR_TASKS.md` - Team tasks

2. **Test specific features:**
   - Create a user account
   - Create a task
   - Generate a challenge
   - Check gamification points

3. **Monitor logs:**
   - Watch service logs for errors
   - Check database connections
   - Verify API calls are routing correctly

---

## Documentation

For new team members, start with:
- **[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)** - Complete setup guide
- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - Environment variable reference
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

**Need Help?** 
- Check `docs/TROUBLESHOOTING.md` for common issues
- Check `GETTING_STARTED.md` or `ENVIRONMENT_VARIABLES.md` for detailed setup information
- Run `bash scripts/fix-dependencies.sh` if you encounter dependency issues

