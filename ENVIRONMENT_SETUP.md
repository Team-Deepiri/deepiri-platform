# Environment Setup Guide

Complete setup guide for new team members joining the Deepiri project.

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

## Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **Node.js** (version 18+) - for local development
- **Python** (version 3.11+) - for local development
- **Git** (version 2.30+)

### Verify Prerequisites

```bash
docker --version
docker-compose --version
node --version
python --version
git --version
```

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Deepiri/deepiri
```

### 2. Set Up Environment Variables

```bash
# Copy example environment files
cp deepiri-core-api/env.example.deepiri-core-api .env.deepiri-core-api
cp diri-cyrex/env.example.diri-cyrex .env.diri-cyrex

# Edit .env files with your configuration
# At minimum, set:
# - OPENAI_API_KEY
# - MONGO_ROOT_PASSWORD
# - REDIS_PASSWORD
```

**For detailed environment variable reference, see [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)**

### 3. Install Dependencies

#### Option A: Automated Script (Recommended)

```bash
# Make script executable (Linux/Mac)
chmod +x scripts/fix-dependencies.sh

# Run the script
bash scripts/fix-dependencies.sh
```

This will:
- ✅ Install all Node.js dependencies for all services
- ✅ Install Python dependencies
- ✅ Verify logger utilities exist
- ✅ Ensure all required packages are available

#### Option B: Manual Installation

**Node.js Services:**
```bash
# Install dependencies for all services
for service in platform-services/backend/*; do
  if [ -f "$service/package.json" ]; then
    echo "Installing $service..."
    cd "$service" && npm install && cd ../..
  fi
done

# Install API server dependencies
cd deepiri-core-api && npm install && cd ..

# Install deepiri-web-frontend dependencies
cd deepiri-web-frontend && npm install && cd ..
```

**Python Backend:**
```bash
cd diri-cyrex
pip install -r requirements.txt
```

### 4. Verify Setup

```bash
# Check that logger utilities exist
find services -name "logger.js" -type f

# Check that dependencies are installed
ls platform-services/backend/deepiri-auth-service/node_modules/axios
python -c "import numpy; print('numpy OK')"
```

## Running Services

### Development Mode (Recommended)

```bash
# Start all services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop all services
docker-compose -f docker-compose.dev.yml down
```

### Production Mode

```bash
# Build and start
docker-compose up -d --build

# View logs
docker-compose logs -f
```

## Service Architecture

### Microservices

| Service | Port | Description |
|---------|------|-------------|
| api-gateway | 5000 | Main API gateway |
| auth-service | 5001 | User management, OAuth |
| task-orchestrator | 5002 | Task management |
| gamification-service | 5003 | Gamification features |
| analytics-service | 5004 | Analytics and metrics |
| notification-service | 5005 | Notifications |
| external-bridge-service | 5006 | External integrations |
| challenge-service | 5007 | Challenge generation |
| realtime-gateway | 5008 | WebSocket connections |
| cyrex | 8000 | AI/ML service |
| deepiri-web-frontend-dev | 5173 | Frontend (dev) |

### Infrastructure Services

| Service | Port | Description |
|---------|------|-------------|
| mongodb | 27017 | MongoDB database |
| redis | 6379 | Redis cache |
| influxdb | 8086 | InfluxDB time-series |
| mongo-express | 8081 | MongoDB admin UI |
| mlflow | 5500 | ML experiment tracking |
| jupyter | 8888 | Jupyter notebooks |

## Project Structure

```
deepiri/
├── platform-services/     # Platform microservices
│   ├── backend/           # Backend microservices
│   │   ├── deepiri-auth-service/
│   │   ├── src/          # Source code
│   │   ├── utils/        # Utilities (logger, etc.)
│   │   ├── package.json  # Dependencies
│   │   └── Dockerfile    # Service Dockerfile
│   ├── task-orchestrator/
│   ├── ...
│   └── shared-utils/     # Shared utilities package
├── deepiri-core-api/           # Main API server
├── deepiri-web-frontend/             # React deepiri-web-frontend
├── diri-cyrex/       # Python AI/ML backend
│   ├── app/             # Application code
│   ├── requirements.txt # Python dependencies
│   └── Dockerfile       # Python Dockerfile
├── scripts/             # Utility scripts
├── docs/                # Documentation
└── docker-compose.dev.yml  # Development compose file
```

## Common Tasks

### Adding a New Dependency

**Node.js Service:**
```bash
cd platform-services/backend/deepiri-auth-service
npm install <package-name> --save
```

**Python Backend:**
```bash
cd diri-cyrex
pip install <package-name>
echo "<package-name>==<version>" >> requirements.txt
```

### Adding a New Service

1. Create service directory: `platform-services/backend/new-service/`
2. Add `package.json` with dependencies
3. Create `Dockerfile`
4. Add service to `docker-compose.dev.yml`
5. Create `utils/logger.js` in the service

### Debugging a Service

```bash
# View logs
docker logs deepiri-auth-service-dev -f

# Execute command in container
docker exec -it deepiri-auth-service-dev sh

# Check service health
curl http://localhost:5001/health
```

### Rebuilding a Service

```bash
# Rebuild specific service
docker-compose -f docker-compose.dev.yml build --no-cache auth-service
docker-compose -f docker-compose.dev.yml up -d auth-service

# Rebuild all services
docker-compose -f docker-compose.dev.yml build --no-cache
docker-compose -f docker-compose.dev.yml up -d
```

## Development Workflow

### 1. Starting Development

```bash
# Start all services
docker-compose -f docker-compose.dev.yml up -d

# Check service status
docker-compose -f docker-compose.dev.yml ps
```

### 2. Making Changes

- **Node.js Services**: Changes are hot-reloaded via volume mounts
- **Python Backend**: May require container restart
- **Frontend**: Vite HMR enabled for instant updates

### 3. Testing Changes

```bash
# Run service tests
cd platform-services/backend/deepiri-auth-service
npm test

# Check service health
curl http://localhost:5001/health
```

### 4. Committing Changes

```bash
# Ensure all dependencies are committed
git add package.json package-lock.json requirements.txt

# Commit changes
git commit -m "Description of changes"
```

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and solutions.

### Quick Fixes

```bash
# Fix all dependencies
bash scripts/fix-dependencies.sh

# Restart all services
docker-compose -f docker-compose.dev.yml restart

# Clean and rebuild
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml build --no-cache
docker-compose -f docker-compose.dev.yml up -d
```

## Best Practices

1. **Always use Docker Compose** for consistency
2. **Run dependency fix script** after pulling changes
3. **Check service health** before starting work
4. **Review logs** when issues occur
5. **Keep dependencies updated** regularly
6. **Document new services** and dependencies

## Related Documentation

- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - Complete environment variable reference
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Troubleshooting guide
- **[START_EVERYTHING.md](START_EVERYTHING.md)** - Complete testing guide
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Local development setup
- **[docs/SHARED_UTILS_ARCHITECTURE.md](docs/SHARED_UTILS_ARCHITECTURE.md)** - Architecture documentation

## Getting Help

- Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) first
- Review service logs: `docker logs <container-name>`
- Check service health endpoints
- Review the relevant architecture documentation

---

**Welcome to the Deepiri team!** 🚀



