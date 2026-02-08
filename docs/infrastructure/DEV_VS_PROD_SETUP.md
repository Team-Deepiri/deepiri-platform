# Development vs Production Docker Setup

This document explains the difference between development and production Docker Compose configurations.

## Development Environment (`docker-compose.dev.yml`)

### Features:
- **Hot Reload**: Code changes are immediately reflected without rebuilding
- **Volume Mounts**: Source code is mounted from host, allowing live editing
- **Dev Commands**: Services run in development mode with auto-reload

### Services Configuration:

#### Node.js Services (API Gateway, Auth, Task Orchestrator, etc.)
- **Volume Mounts**: 
  - Source code: `./platform-services/backend/{service}:/app`
  - Shared utils: `./platform-services/shared/deepiri-shared-utils:/shared-utils`
  - Excluded: `/app/node_modules` (uses container's node_modules)
- **Command**: `npm run dev` (uses `ts-node-dev` for hot reload)
- **Auto-reload**: Changes to `.ts` files trigger automatic restart

#### Python Service (Cyrex)
- **Volume Mounts**:
  - App code: `./diri-cyrex/app:/app/app`
  - Training: `./diri-cyrex/train:/app/train`
  - Inference: `./diri-cyrex/inference:/app/inference`
  - Cache: `cyrex_cache:/app/.cache` (persistent)
- **Command**: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --reload-dir /app/app`
- **Auto-reload**: Changes to `.py` files trigger automatic restart

#### Frontend
- **Volume Mounts**: `./deepiri-web-frontend:/app`
- **Hot Reload**: Vite's built-in HMR (Hot Module Replacement)

### Usage:
```bash
# Start all services in dev mode
docker compose -f docker-compose.dev.yml up -d

# View logs
docker compose -f docker-compose.dev.yml logs -f

# Restart a service (if needed)
docker compose -f docker-compose.dev.yml restart api-gateway
```

### When to Rebuild:
- **Dependencies change**: When `package.json`, `requirements.txt`, or `Dockerfile` changes
- **First time setup**: Initial build required
- **Shared utils change**: May need rebuild if shared-utils structure changes

```bash
# Rebuild specific service
docker compose -f docker-compose.dev.yml build api-gateway

# Rebuild all services
docker compose -f docker-compose.dev.yml build
```

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

## Production Environment (`docker-compose.yml`)

### Features:
- **Optimized Builds**: Services use pre-built, optimized images
- **No Volume Mounts**: Code is baked into images (immutable)
- **Production Commands**: Services run compiled/built code
- **Better Performance**: No transpilation overhead

### Services Configuration:

#### Node.js Services
- **No Volume Mounts**: Code is copied during build
- **Command**: `node dist/server.js` (runs compiled TypeScript)
- **Build Process**: TypeScript compiled to JavaScript during image build

#### Python Service (Cyrex)
- **No Volume Mounts**: Code is copied during build
- **Command**: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1` (production mode)
- **No Reload**: Production mode for stability

### Usage:
```bash
# Build production images
docker compose build

# Start production services
docker compose up -d

# View logs
docker compose logs -f
```

## Key Differences

| Feature | Development | Production |
|---------|------------|------------|
| **Code Changes** | Instant (hot reload) | Requires rebuild |
| **Volume Mounts** | Yes (source code) | No (baked in) |
| **Command** | `npm run dev` / `uvicorn --reload` | `node dist/` / `uvicorn --workers` |
| **Performance** | Slower (transpilation on fly) | Faster (pre-compiled) |
| **Memory** | Higher (dev tools) | Lower (optimized) |
| **Use Case** | Local development | Deployment |

## Best Practices

### Development:
1. **Edit code directly** - Changes reflect immediately
2. **Only rebuild** when dependencies change
3. **Use dev compose** for all local work
4. **Check logs** if changes don't appear (may need service restart)

### Production:
1. **Always rebuild** before deploying
2. **Test production builds** locally before deployment
3. **Use production compose** for staging/production environments
4. **Tag images** for version control

## Troubleshooting

### Dev Mode: Changes Not Reflecting
1. Check volume mounts are correct: `docker compose -f docker-compose.dev.yml config`
2. Verify service is running: `docker compose -f docker-compose.dev.yml ps`
3. Check logs for errors: `docker compose -f docker-compose.dev.yml logs {service}`
4. Restart service: `docker compose -f docker-compose.dev.yml restart {service}`

### Dev Mode: Dependencies Not Updating
- Rebuild the service: `docker compose -f docker-compose.dev.yml build {service}`
- Restart: `docker compose -f docker-compose.dev.yml up -d {service}`

### Production: Build Fails
- Check Dockerfile syntax
- Verify all dependencies in package.json/requirements.txt
- Check build logs: `docker compose build --progress=plain {service}`

