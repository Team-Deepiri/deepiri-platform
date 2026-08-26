# Deepiri Platform (cloud portal)

> **Cloud VPS** internal portal — auth, org, tools, Plaky. No Cyrex / LIS / AI runtime.  
> **Full local builder stack** → [Team-Deepiri/deepiri-control-plane](https://github.com/Team-Deepiri/deepiri-control-plane) (`docker-compose.dev.yml`, `setup-deepiri-dev.sh`, speech engine).

Deploy: `docker compose up -d` (see `docker-compose.yml`)  
Dev setup for Cyrex/LIS/speech: clone **deepiri-control-plane** and run `bash setup-deepiri-dev.sh`

> **NEW TO THE PROJECT?** [docs/getting-started/START_HERE.md](docs/getting-started/START_HERE.md)  
> **FIND YOUR TEAM:** [docs/getting-started/FIND_YOUR_TASKS.md](docs/getting-started/FIND_YOUR_TASKS.md)  
> **Architecture split:** [docs/architecture/REPO_SPLIT.md](docs/architecture/REPO_SPLIT.md)

## Quick Start

### Setup script (Recommended)

Download `setup-deepiri-dev.sh` from this repo and save it to any directory on your system. Run the script from your terminal and follow the instruction

```bash
# From the same working directory as the script
bash setup-deepiri-dev.sh
```

Alternatively, you can also clone the repository and run the setup script directly from the project root

```bash
# Clone the repository
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform

# Run the install script
bash setup-deepiri-dev.sh
```

### Manual install

```bash
# 1. Clone the repository
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform

# 2. Pull submodules for your team (see teams/<team>.yml)
./setup-deepiri-dev.sh pull ai-team

# 3. Build services
./setup-deepiri-dev.sh build ai-team

# 4. Start the full stack
./setup-deepiri-dev.sh start ai-team

# OR use docker compose directly
docker compose -f docker-compose.dev.yml up -d <service>

# All services

docker compose -f docker-compose.dev.yml up -d
```

### Access services
- Frontend: http://localhost:5173
- API Gateway: http://localhost:5100
- Cyrex AI: http://localhost:8000
- Synapse: http://localhost:8002
- MLflow: http://localhost:5500

## Prerequisites

- Docker & Docker Compose
- Git
- 8GB+ RAM recommended
- **For Windows user**: A WSL2 instance running a Debian-based distro

## Team Development Environments

Each team has its own service/submodule catalog in `teams/<team>.yml`, driven by `setup-deepiri-dev.sh`:

| Team | Catalog | Description |
|------|---------|--------------|
| Backend | `teams/backend-team.yml` | Backend microservices |
| AI | `teams/ai-team.yml` | AI/ML services (Cyrex, MLflow, speech) |
| Frontend | `teams/frontend-team.yml` | Web frontend |
| ML | `teams/ml-team.yml` | Machine learning pipelines |
| Infrastructure | `teams/infrastructure-team.yml` | Infrastructure services |
| Platform | `teams/platform-engineers.yml` | All services |
| QA | `teams/qa-team.yml` | QA testing environment |

### Team-Specific Setup

```bash
# Backend Team
./setup-deepiri-dev.sh build backend-team && ./setup-deepiri-dev.sh start backend-team

# AI Team
./setup-deepiri-dev.sh build ai-team && ./setup-deepiri-dev.sh start ai-team

# Frontend Team
./setup-deepiri-dev.sh build frontend-team && ./setup-deepiri-dev.sh start frontend-team
```

## Services

### Backend Microservices

| Service | Port | Description |
|---------|------|-------------|
| API Gateway | 5100 | Main entry point, routes requests to backend services |
| Auth Service | 5001 | User authentication, JWT tokens, login/register |
| Task Orchestrator | 5002 | Manages and tracks user tasks and workflows |
| Engagement Service | 5003 | Gamification: quests, streaks, leaderboards, rewards |
| Platform Analytics | 5004 | Tracks user events, metrics, and analytics data |
| Notification Service | 5005 | Push notifications, email notifications |
| External Bridge | 5006 | Integrates with external APIs and third-party services |
| Challenge Service | 5007 | User challenges, competitions, achievements |
| Realtime Gateway | 5008 | WebSocket server for real-time features |
| Messaging Service | 5009 | In-app messaging, chat functionality |
| Language Intelligence | 5010 | NLP, text processing, language capabilities |
| PrismPipe | 5011 | Capability-routed API pipeline - transforms requests through nodes |

### AI/ML Services

| Service | Port | Description |
|---------|------|-------------|
| Cyrex | 8000 | AI agent service - LLM orchestration, tool calling, agent workflows |
| Cyrex Interface | 5175 | Web UI for testing and interacting with Cyrex agents |
| Jupyter | 8888 | Jupyter notebooks for AI research and experimentation |
| MLflow | 5500 | ML experiment tracking, model registry, metrics |
| Ollama | 11434 | Local LLM inference runtime |

### Infrastructure

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Primary database - users, tasks, quests, metadata |
| Redis | 6379 | In-memory cache, session storage, pub/sub |
| InfluxDB | 8086 | Time-series database for analytics and metrics |
| Minio | 9000 | S3-compatible object storage for files |
| Milvus | 19530 | Vector database for embeddings and AI |
| pgAdmin | 5050 | PostgreSQL admin web interface |
| Adminer | 8080 | Database management web interface |
| Synapse | 8002 | Matrix server for decentralized chat |
| etcd | 2379 | Distributed key-value store for cluster state |

## Submodule Management

The platform uses git submodules for service repositories, scoped per team in `teams/<team>.yml`:

```bash
# Pull submodules for a specific team
./setup-deepiri-dev.sh pull backend-team

# Pull all submodules
./setup-deepiri-dev.sh pull all-services
```

### Available Submodules

- `deepiri-core-api` - Core API
- `diri-cyrex` - AI/ML service
- `deepiri-api-gateway` - API Gateway
- `deepiri-auth-service` - Authentication
- `deepiri-external-bridge-service` - External integrations
- `deepiri-web-frontend` - Web frontend
- `diri-helox` - ML training pipelines
- `deepiri-modelkit` - Shared contracts
- `deepiri-language-intelligence-service` - Language processing
- `deepiri-prismpipe` - Cyrex AGI execution engine (Poetry git tag on `diri-cyrex`, not a platform submodule)
- `platform-services/shared/deepiri-synapse` - Matrix server
- `platform-services/shared/deepiri-sugar-glider` - Synapse stream bridge runtime

## Common Commands

```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Start all services
docker compose -f docker-compose.dev.yml up -d

# Stop all services
docker compose -f docker-compose.dev.yml down

# View logs
docker compose -f docker-compose.dev.yml logs -f

# View specific service logs
docker compose -f docker-compose.dev.yml logs -f cyrex

# Restart service
docker compose -f docker-compose.dev.yml restart cyrex

# Check status
docker compose -f docker-compose.dev.yml ps
```

## Project Structure

```
deepiri-platform/
├── platform-services/
│   ├── backend/
│   │   ├── deepiri-api-gateway/
│   │   ├── deepiri-auth-service/
│   │   ├── deepiri-task-orchestrator/
│   │   ├── deepiri-engagement-service/
│   │   ├── deepiri-platform-analytics-service/
│   │   ├── deepiri-notification-service/
│   │   ├── deepiri-external-bridge-service/
│   │   ├── deepiri-challenge-service/
│   │   ├── deepiri-realtime-gateway/
│   │   ├── deepiri-messaging-service/
│   │   └── deepiri-language-intelligence-service/
│   └── shared/
│       ├── deepiri-synapse/        # Matrix server
│       ├── deepiri-sugar-glider/   # Synapse stream bridge runtime
│       └── deepiri-shared-utils/  # Shared utilities
├── diri-cyrex/                     # AI/ML service (Poetry: deepiri-prismpipe@v0.2.1)
├── diri-helox/                     # ML training pipelines
├── deepiri-web-frontend/          # React frontend
├── deepiri-modelkit/              # Shared contracts
├── teams/                        # Per-team service/submodule catalogs (*.yml)
├── setup-deepiri-dev.sh          # Onboard + day-to-day team ops (pull/build/start)
├── docs/                         # Documentation
└── docker-compose.dev.yml        # Development configuration
```

## Documentation

- [Getting Started](docs/getting-started/START_HERE.md)
- [Find Your Tasks](docs/getting-started/FIND_YOUR_TASKS.md)
- [Service Communication](SERVICE_COMMUNICATION_AND_TEAMS.md)
- [Environment Variables](docs/getting-started/ENVIRONMENT_VARIABLES.md)
- [Building Services](HOW_TO_BUILD.md)

## Contributing

1. Clone the repository
2. Initialize submodules for your team
3. Create a feature branch
4. Make your changes
5. Build and test
6. Submit a pull request

## License

See [LICENSE.md](LICENSE.md)
