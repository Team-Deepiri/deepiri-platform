# Deepiri Platform

> **NEW TO THE PROJECT?** Start here: [docs/getting-started/START_HERE.md](docs/getting-started/START_HERE.md)  
> **FIND YOUR TEAM:** [docs/getting-started/FIND_YOUR_TASKS.md](docs/getting-started/FIND_YOUR_TASKS.md)  
> **Quick Start (All Services):** Run `team_dev_environments/platform-engineers/start.sh` or use docker compose directly

## Quick Start

```bash
# 1. Clone the repository
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform

# 2. Initialize submodules
./team_submodule_commands/platform-engineers/pull_submodules.sh

# 3. Build all services
./team_dev_environments/platform-engineers/build.sh

# 4. Start the full stack
./team_dev_environments/platform-engineers/start.sh

# OR use docker compose directly
docker compose -f docker-compose.dev.yml up -d

# 5. Access services
# - Frontend: http://localhost:5173
# - API Gateway: http://localhost:5100
# - Cyrex AI: http://localhost:8000
# - Synapse: http://localhost:8002
# - MLflow: http://localhost:5500
```

## Prerequisites

- Docker & Docker Compose
- Git
- 8GB+ RAM recommended

## Team Development Environments

Each team has its own development environment in `team_dev_environments/`:

| Team | Path | Description |
|------|------|-------------|
| Backend | `team_dev_environments/backend-team/` | Backend microservices |
| AI | `team_dev_environments/ai-team/` | AI/ML services (Cyrex, MLflow) |
| Frontend | `team_dev_environments/frontend-team/` | Web frontend |
| ML | `team_dev_environments/ml-team/` | Machine learning pipelines |
| Infrastructure | `team_dev_environments/infrastructure-team/` | Infrastructure services |
| Platform | `team_dev_environments/platform-engineers/` | All services |
| QA | `team_dev_environments/qa-team/` | QA testing environment |

### Team-Specific Setup

```bash
# Backend Team
cd team_dev_environments/backend-team
./build.sh && ./start.sh

# AI Team
cd team_dev_environments/ai-team
./build.sh && ./start.sh

# Frontend Team
cd team_dev_environments/frontend-team
./build.sh && ./start.sh
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

The platform uses git submodules for service repositories. Use the team-specific scripts:

```bash
# Pull submodules for a specific team
./team_submodule_commands/backend-team/pull_submodules.sh

# Update all submodules
./team_submodule_commands/all_submodules/pull_submodules.sh
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
- `platform-services/shared/deepiri-prismpipe` - PrismPipe pipeline
- `platform-services/shared/deepiri-synapse` - Matrix server

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
│       ├── deepiri-prismpipe/      # Capability-routed API pipeline
│       ├── deepiri-synapse/       # Matrix server
│       └── deepiri-shared-utils/  # Shared utilities
├── diri-cyrex/                     # AI/ML service
├── diri-helox/                     # ML training pipelines
├── deepiri-web-frontend/          # React frontend
├── deepiri-modelkit/              # Shared contracts
├── team_dev_environments/         # Team-specific environments
├── team_submodule_commands/       # Submodule management scripts
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
