# Troubleshooting Guide

This guide addresses common issues when setting up and running Deepiri services.

## Table of Contents

1. [Jupyter Service Permission Issues](#jupyter-service-permission-issues)
2. [Missing Node.js Dependencies](#missing-nodejs-dependencies)
3. [Missing Python Dependencies](#missing-python-dependencies)
4. [Module Resolution Issues](#module-resolution-issues)
5. [Docker Build Issues](#docker-build-issues)
6. [Service Connection Issues](#service-connection-issues)

---

## Jupyter Service Permission Issues

### Problem
```
Permission denied when creating directories in /home/appuser
```

### Solution

The Jupyter service now uses a dedicated Dockerfile (`Dockerfile.jupyter`) that properly handles permissions:

1. **Proper User Setup**: The Dockerfile creates the `appuser` with a home directory and proper permissions
2. **Runtime Directory**: Jupyter runtime files are stored in `/tmp/jupyter_runtime` (writable by all users)
3. **Configuration**: Jupyter is configured to use writable directories

### Verification

```bash
# Check if Jupyter container is running
docker ps | grep jupyter

# Check Jupyter logs
docker logs deepiri-jupyter-dev

# Access Jupyter at http://localhost:8888
```

### Manual Fix (if needed)

If you still encounter permission issues:

```bash
# Rebuild the Jupyter container
docker-compose -f docker-compose.dev.yml build --no-cache jupyter
docker-compose -f docker-compose.dev.yml up -d jupyter
```

---

## Missing Node.js Dependencies

### Problem
```
Cannot find module 'axios'
Cannot find module 'express'
```

### Solution

All required dependencies are listed in each service's `package.json`. To install:

#### Option 1: Use the Fix Script (Recommended)

```bash
# Run the dependency fix script
bash scripts/fix-dependencies.sh
```

#### Option 2: Manual Installation

```bash
# Install dependencies for a specific service
cd platform-services/backend/deepiri-auth-service
npm install

# Or install all services
for service in platform-services/backend/*; do
  if [ -f "$service/package.json" ]; then
    echo "Installing $service..."
    cd "$service" && npm install && cd ../..
  fi
done
```

#### Option 3: Docker Rebuild

```bash
# Rebuild all services (will install dependencies)
docker-compose -f docker-compose.dev.yml build --no-cache
```

### Common Missing Dependencies

| Service | Common Dependencies |
|---------|-------------------|
| auth-service | axios, express, mongoose, winston |
| task-orchestrator | axios, express, mongoose, winston |
| gamification-service | axios, express, mongoose, redis, winston |
| analytics-service | axios, express, mongoose, @influxdata/influxdb-client |
| external-bridge-service | axios, express, passport, winston |
| notification-service | express, socket.io, firebase-admin, winston |

### Verification

```bash
# Check if dependencies are installed
cd platform-services/backend/deepiri-auth-service
ls node_modules/axios

# Or check package.json
cat platform-services/backend/deepiri-auth-service/package.json | grep axios
```

---

## Missing Python Dependencies

### Problem
```
No module named 'numpy'
No module named 'torch'
```

### Solution

All Python dependencies are listed in `diri-cyrex/requirements.txt`. To install:

#### Option 1: Use the Fix Script

```bash
bash scripts/fix-dependencies.sh
```

#### Option 2: Manual Installation

```bash
cd diri-cyrex
pip install -r requirements.txt
```

#### Option 3: Docker Rebuild

```bash
docker-compose -f docker-compose.dev.yml build --no-cache cyrex
```

### Key Dependencies

- **Core**: fastapi, uvicorn, pydantic
- **AI/ML**: torch, transformers, numpy, pandas, scikit-learn
- **Embeddings**: sentence-transformers
- **Analytics**: influxdb-client
- **Optional**: pinecone-client, weaviate-client

### Verification

```bash
# Check if numpy is installed
docker exec deepiri-cyrex-dev python -c "import numpy; print(numpy.__version__)"

# Or check requirements
cat diri-cyrex/requirements.txt | grep numpy
```

---

## Module Resolution Issues

### Problem
```
Cannot find module '../../utils/logger'
Error: Cannot find module '../utils/logger'
```

### Solution

Each service has its own logger utility in `services/{service}/utils/logger.js`.

### File Structure

```
services/
├── auth-service/
│   ├── utils/
│   │   └── logger.js          ✅ Logger exists here
│   └── src/
│       └── oauthService.js    ✅ Imports: require('../../utils/logger')
│
├── task-orchestrator/
│   ├── utils/
│   │   └── logger.js          ✅ Logger exists here
│   └── src/
│       └── taskVersioningService.js  ✅ Imports: require('../../utils/logger')
│
└── external-bridge-service/
    ├── utils/
    │   └── logger.js          ✅ Logger exists here
    └── src/
        └── webhookService.js  ✅ Imports: require('../../utils/logger')
```

### Verification

```bash
# Check if logger files exist
find platform-services/backend -name "logger.js" -type f

# Should output:
# platform-services/backend/deepiri-auth-service/utils/logger.js
# platform-services/backend/deepiri-task-orchestrator/utils/logger.js
# platform-services/backend/deepiri-engagement-service/utils/logger.js
# platform-services/backend/deepiri-platform-analytics-service/utils/logger.js
# platform-services/backend/deepiri-notification-service/utils/logger.js
# platform-services/backend/deepiri-external-bridge-service/utils/logger.js
```

### If Logger is Missing

The logger utility should be automatically created. If it's missing:

1. Check that the `utils/` directory exists in the service
2. Verify the logger.js file exists
3. Rebuild the Docker container

```bash
# Rebuild a specific service
docker-compose -f docker-compose.dev.yml build --no-cache auth-service
```

---

## Docker Build Issues

### Problem: Build Freezing at Step 113/120 (Cyrex Service)

**Symptoms:**
- Build freezes at step 113/120
- WiFi disconnects during build
- Large CUDA package downloads (1.5GB+)

**Solution: Use Auto GPU Detection with CPU Fallback**

The build system now automatically detects your GPU and uses CPU fallback if needed:

```bash
# Auto-detect GPU and build (recommended)
# Windows
.\scripts\build-cyrex-auto.ps1

# Linux/Mac
./scripts/build-cyrex-auto.sh
```

This will:
- ✅ Detect if you have a GPU (≥4GB VRAM)
- ✅ Use CUDA image if GPU is good enough
- ✅ Fall back to CPU image if no GPU (faster, no freezing!)
- ✅ Use prebuilt PyTorch images (no 1.5GB downloads)

**Force CPU Build (if auto-detection doesn't work):**

```bash
# Windows PowerShell
$env:BASE_IMAGE = "pytorch/pytorch:2.0.0-cpu"
docker compose -f docker-compose.dev.yml build cyrex

# Linux/Mac
BASE_IMAGE=pytorch/pytorch:2.0.0-cpu docker compose -f docker-compose.dev.yml build cyrex
```

**See:** `diri-cyrex/README_BUILD.md` for detailed GPU detection guide.

### Problem: npm ci can only install with an existing package-lock.json

**Solution:**

The Dockerfiles have been updated to use `npm install` instead of `npm ci` when `package-lock.json` is missing.

**Current Dockerfile Pattern:**

```dockerfile
COPY package*.json ./
RUN npm install --omit=dev --legacy-peer-deps && npm cache clean --force
```

### If Build Still Fails

1. **Clear Docker cache**:
   ```bash
   docker system prune -a
   ```

2. **Rebuild without cache**:
   ```bash
   docker-compose -f docker-compose.dev.yml build --no-cache
   ```

3. **Check Dockerfile syntax**:
   ```bash
   docker build -t test -f platform-services/backend/deepiri-auth-service/Dockerfile platform-services/backend/deepiri-auth-service
   ```

---

## Service Connection Issues

### Problem
```
Cannot connect to MongoDB
Cannot connect to Redis
Service not responding
```

### Solution

1. **Check service health**:
   ```bash
   # Check all services
   docker-compose -f docker-compose.dev.yml ps
   
   # Check specific service logs
   docker logs deepiri-auth-service-dev
   ```

2. **Verify environment variables**:
   ```bash
   # Check .env file exists
   ls -la .env
   
   # Check environment in container
   docker exec deepiri-auth-service-dev env | grep MONGO
   ```

3. **Check network connectivity**:
   ```bash
   # Test MongoDB connection
   docker exec deepiri-auth-service-dev curl http://mongodb:27017
   
   # Test Redis connection
   docker exec deepiri-engagement-service-dev redis-cli -h redis ping
   ```

4. **Restart services**:
   ```bash
   docker-compose -f docker-compose.dev.yml restart
   ```

---

## Quick Diagnostic Commands

```bash
# Check all services status
docker-compose -f docker-compose.dev.yml ps

# View logs for all services
docker-compose -f docker-compose.dev.yml logs

# Check service health endpoints
curl http://localhost:5001/health  # auth-service
curl http://localhost:5002/health  # task-orchestrator
curl http://localhost:5000/health  # api-gateway
curl http://localhost:8000/health  # cyrex

# Check dependencies
cd platform-services/backend/deepiri-auth-service && npm list --depth=0
cd diri-cyrex && pip list | grep numpy

# Rebuild everything
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml build --no-cache
docker-compose -f docker-compose.dev.yml up -d
```

---

## Getting Help

If you encounter issues not covered here:

1. Check service logs: `docker logs <container-name>`
2. Review the [Architecture Documentation](SHARED_UTILS_ARCHITECTURE.md)
3. Check the [Start Guide](START_EVERYTHING.md)
4. Review service-specific README files in each service directory

---

## Prevention

To avoid these issues in the future:

1. **Always run the dependency fix script** after pulling changes:
   ```bash
   bash scripts/fix-dependencies.sh
   ```

2. **Use Docker Compose** for consistent environments:
   ```bash
   docker-compose -f docker-compose.dev.yml up -d
   ```

3. **Keep dependencies updated**:
   ```bash
   # Update Node.js dependencies
   npm update --workspace=platform-services/backend/*
   
   # Update Python dependencies
   pip install --upgrade -r diri-cyrex/requirements.txt
   ```

4. **Generate package-lock.json files** for reproducible builds:
   ```bash
   for service in platform-services/backend/*; do
     if [ -f "$service/package.json" ]; then
       cd "$service" && npm install && cd ../..
     fi
   done
   ```




