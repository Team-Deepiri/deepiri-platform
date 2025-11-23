# Deepiri - AI-Powered Learning Platform

> **Quick Start:** Run `./build.sh` (Linux/Mac/WSL) or `.\build.ps1` (Windows), then `docker compose -f docker-compose.dev.yml up -d`

## What is Deepiri?

Deepiri is an AI-powered learning and development platform featuring:
- 🤖 AI agents (Cyrex) for intelligent assistance
- 🎮 Gamification and challenges
- 📊 Real-time analytics
- 🔔 Notifications and webhooks
- 🌐 External integrations (GitHub, Notion, Trello)
- 📝 Jupyter notebooks for research

## Getting Started

### Prerequisites
- Docker & Docker Compose
- WSL2 (Windows only)
- 8GB+ RAM recommended

### Build & Run

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd deepiri

# 2. Build all services (auto-cleans dangling images)
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell

# 3. Start the stack
docker compose -f docker-compose.dev.yml up -d

# 4. Access services
# - Frontend: http://localhost:5173
# - API Gateway: http://localhost:5000
# - Cyrex AI: http://localhost:8000
# - Jupyter: http://localhost:8888
# - MLflow: http://localhost:5500
```

### Stop

```bash
docker compose -f docker-compose.dev.yml down
```

## Documentation

### Essential Guides
- **[HOW_TO_BUILD.md](HOW_TO_BUILD.md)** - THE definitive build guide
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup walkthrough
- **[SERVICE_COMMUNICATION_AND_TEAMS.md](SERVICE_COMMUNICATION_AND_TEAMS.md)** - Architecture overview

### Environment Setup
- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - All environment variables
- **[docker-compose.dev.yml](docker-compose.dev.yml)** - Development configuration

### Troubleshooting
- **[scripts/STORAGE-TROUBLESHOOTING.md](scripts/STORAGE-TROUBLESHOOTING.md)** - Disk space issues
- **[docs/LOG_INSPECTION_GUIDE.md](docs/LOG_INSPECTION_GUIDE.md)** - Debugging logs

### Team-Specific
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
- **Jupyter** (Port 8888) - Research notebooks
- **MLflow** (Port 5500) - Experiment tracking

### Infrastructure
- **MongoDB** (Port 27017) - Primary database
- **Redis** (Port 6380) - Cache & sessions
- **InfluxDB** (Port 8086) - Time-series analytics

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

1. Make code changes
2. Run `./build.sh` (or `.\build.ps1`)
3. Run `docker compose -f docker-compose.dev.yml restart <service>`
4. Check logs with `docker compose -f docker-compose.dev.yml logs -f <service>`

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

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `./build.sh` to test
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

See [LICENSE.md](LICENSE.md)

## Support

- Documentation: See `docs/` directory
- Issues: Use GitHub issues
- Architecture: See [SERVICE_COMMUNICATION_AND_TEAMS.md](SERVICE_COMMUNICATION_AND_TEAMS.md)

---

**Note:** Old Skaffold-based build docs are archived in `docs/archive/skaffold/` for reference only. Use the Docker Compose workflow documented in [HOW_TO_BUILD.md](HOW_TO_BUILD.md).
