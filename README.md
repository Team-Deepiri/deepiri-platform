# Deepiri 

> **NEW TO THE PROJECT?** Start here: [START_HERE.md](START_HERE.md)  
> **FIND YOUR TEAM:** [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)  
> **🌟 Quick Start (All Services):** `python run_dev.py` - Runs full stack with K8s config!


### For New Team Members

1. **Find your roles:** [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)
2. **Follow your team's path:** [START_HERE.md](START_HERE.md)
3. **Git hooks:** Automatically configured on clone (protects main and dev branches)

### Quick Build & Run

```bash
# 1. Clone the repository
git clone <deepiri-platform repo>
cd deepiri-platform

# 2. One-time setup
pip install pyyaml
touch ops/k8s/secrets/secrets.yaml  # Create empty secrets file (see ops/k8s/secrets/README.md)

# 3. Build all services (auto-cleans dangling images)
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell

# 4. Start the full stack (with K8s config!)
python run_dev.py       # 🌟 Recommended - loads k8s configmaps & secrets

# OR use docker compose directly
docker compose -f docker-compose.dev.yml up -d

# 5. Access services
# - Frontend: http://localhost:5173
# - API Gateway: http://localhost:5100
# - Cyrex AI: http://localhost:8000
# - Jupyter: http://localhost:8888
# - MLflow: http://localhost:5500
```

### Prerequisites
- Docker & Docker Compose
- WSL2 (Windows only)
- 8GB+ RAM recommended

### Stop All Services

```bash
docker compose -f docker-compose.dev.yml down
```

**Pro Tip:** Use `python run_dev.py` instead of `docker compose` - it auto-loads your k8s config!

## Documentation

### Essential Guides
- **[RUN_DEV_GUIDE.md](RUN_DEV_GUIDE.md)** - 🌟 Run full stack with `python run_dev.py`
- **[team_dev_environments/QUICK_START.md](team_dev_environments/QUICK_START.md)** - Team-specific environments
- **[HOW_TO_BUILD.md](HOW_TO_BUILD.md)** - THE definitive build guide
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup walkthrough
- **[SERVICE_COMMUNICATION_AND_TEAMS.md](SERVICE_COMMUNICATION_AND_TEAMS.md)** - Architecture overview

### Environment Setup
- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - All environment variables (includes k8s config integration)
- **[docker-compose.dev.yml](docker-compose.dev.yml)** - Development configuration
- **[ops/k8s/](ops/k8s/)** - Kubernetes configmaps and secrets (also used by Docker Compose)

### Troubleshooting
- **[scripts/STORAGE-TROUBLESHOOTING.md](scripts/STORAGE-TROUBLESHOOTING.md)** - Disk space issues
- **[docs/LOG_INSPECTION_GUIDE.md](docs/LOG_INSPECTION_GUIDE.md)** - Debugging logs

### Team-Specific (Find Your Team First!)
- **👉 Start here:** [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md) - Find your team and role
- **👉 Complete setup:** [START_HERE.md](START_HERE.md) - Step-by-step getting started guide
- **[docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md)** - AI/ML development
- **[docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md)** - Backend services
- **[docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)** - Frontend development

## Architecture

### Microservices
- **API Gateway** (Port 5000) - Routes all requests
- **Auth Service** (Port 5001) - Authentication & authorization
- **Task Orchestrator** (Port 5002) - Task management
- **Engagement Service** (Port 5003) - Gamification
- **Platform Analytics** (Port 5004) - Analytics
- **Notification Service** (Port 5005) - Notifications
- **External Bridge** (Port 5006) - External integrations
- **Challenge Service** (Port 5007) - Challenges
- **Realtime Gateway** (Port 5008) - WebSockets

### AI/ML Services
- **Cyrex** (Port 8000) - AI agent API
- **Cyrex UI** (Port 5175) - UI for AI agent testing
- **Jupyter** (Port 8888) - Research notebooks
- **MLflow** (Port 5500) - Experiment tracking

### Infrastructure
- **PostgreSQL** (Port 5432) - Primary database for users, roles, tasks, quests, metadata
- **Redis** (Port 6380) - Cache & sessions
- **InfluxDB** (Port 8086) - Time-series analytics

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

**🌟 Recommended:** Use Python scripts (professional K8s-like workflow):
```bash
cd team_dev_environments/backend-team
python run.py         # Auto-loads k8s configmaps & secrets!
```

**Alternative:** Use shell scripts:
```bash
cd team_dev_environments/backend-team
./start.sh            # Linux/Mac
.\start.ps1           # Windows
```

**Or use docker compose directly:**
```bash
docker compose -f docker-compose.backend-team.yml up -d
```

**👉 Python scripts are recommended** - they mimic Kubernetes by loading config from `ops/k8s/` automatically. No `.env` files needed!

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

## Common Commands

```bash
# Build specific service
./build.sh cyrex

# View logs
docker compose -f docker-compose.dev.yml logs -f

# View specific service logs
docker compose -f docker-compose.dev.yml logs -f cyrex

# Check status
docker compose -f docker-compose.dev.yml ps

# Restart service
docker compose -f docker-compose.dev.yml restart cyrex

# Clean up disk space
./scripts/remove-dangling-images.sh        # Linux/Mac/WSL
.\scripts\remove-dangling-images.ps1       # Windows
```

## Development Workflow

### With Hot Reload (Recommended)
1. Make code changes → **Changes appear immediately** (no rebuild needed!)
2. Only rebuild when dependencies change (`package.json`/`requirements.txt`)
3. Check logs: `docker compose -f docker-compose.dev.yml logs -f <service>`

### Without Hot Reload (if needed)
1. Make code changes
2. Run `./build.sh <service>` (or `.\build.ps1 <service>`)
3. Run `docker compose -f docker-compose.dev.yml restart <service>`
4. Check logs: `docker compose -f docker-compose.dev.yml logs -f <service>`

The build scripts automatically clean up dangling Docker images, so you never get disk space bloat.

## Project Structure

```
deepiri/
├── deepiri-core-api/          # Legacy monolith (deprecated)
├── platform-services/         # Microservices
│   └── backend/
│       ├── deepiri-api-gateway/
│       ├── deepiri-auth-service/
│       ├── deepiri-task-orchestrator/
│       └── ... (other services)
├── diri-cyrex/               # AI/ML service
├── deepiri-web-frontend/     # React frontend
├── ops/                      # Kubernetes configs
├── scripts/                  # Utility scripts
├── docs/                     # Documentation
├── build.sh / build.ps1      # Build scripts
└── docker-compose.dev.yml    # Development config
```

## Contributing

1. **Git hooks:** Automatically configured on clone (protects main and dev branches)
2. Fork the repository
3. Create a feature branch (NOT from main or dev)
4. Make your changes
5. Run `./build.sh` to test
6. Submit a pull request to `staging` (NOT main or dev)

See [CONTRIBUTING.md](CONTRIBUTING.md) for complete workflow details.

## License

See [LICENSE.md](LICENSE.md)

## Support

- Documentation: See `docs/` directory
- Issues: Use GitHub issues
- Architecture: See [SERVICE_COMMUNICATION_AND_TEAMS.md](SERVICE_COMMUNICATION_AND_TEAMS.md)

---

**Note:** Old Skaffold-based build docs are archived in `docs/archive/skaffold/` for reference only. Use the Docker Compose workflow documented in [HOW_TO_BUILD.md](HOW_TO_BUILD.md).




