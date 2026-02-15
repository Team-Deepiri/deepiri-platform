# Team-Specific Skaffold Configurations

## Overview

Each team has their own Skaffold configuration file that only builds the services they need. This speeds up builds and reduces resource usage.

## Available Team Configs

| Team | Config File | Services Built |
|------|-------------|----------------|
| **AI Team** | `skaffold-ai-team.yaml` | Cyrex, Jupyter, Challenge Service |
| **ML Team** | `skaffold-ml-team.yaml` | Cyrex, Jupyter, Analytics Service |
| **Infrastructure Team** | `skaffold-infrastructure-team.yaml` | All services |
| **Backend Team** | `skaffold-backend-team.yaml` | All backend microservices |
| **Frontend Team** | `skaffold-frontend-team.yaml` | Frontend + API Gateway + Realtime Gateway + Backend services |
| **QA Team** | `skaffold-qa-team.yaml` | All services (for E2E testing) |
| **Platform Engineers** | `skaffold-platform-engineers.yaml` | All services (for platform tooling) |

## Main Dev Config

**`skaffold-local.yaml`** - Contains ALL services (use `dev-compose` profile for Docker Compose)

## Usage

### Build with Your Team's Config

```bash
# AI Team
skaffold build -f skaffold-ai-team.yaml

# ML Team
skaffold build -f skaffold-ml-team.yaml

# Backend Team
skaffold build -f skaffold-backend-team.yaml

# Frontend Team
skaffold build -f skaffold-frontend-team.yaml

# Infrastructure Team
skaffold build -f skaffold-infrastructure-team.yaml

# QA Team
skaffold build -f skaffold-qa-team.yaml

# Platform Engineers
skaffold build -f skaffold-platform-engineers.yaml
```

### Then Tag and Run with Docker Compose

```bash
# After building, tag images with :latest
eval $(minikube docker-env)
./scripts/tag-skaffold-to-latest.sh

# Run Docker Compose (won't build - uses existing images!)
docker compose -f docker-compose.dev.yml up -d
```

## Team-Specific Services

### AI Team
- `deepiri-dev-cyrex:latest`
- `deepiri-dev-jupyter:latest`
- `deepiri-dev-challenge-service:latest`

### ML Team
- `deepiri-dev-cyrex:latest`
- `deepiri-dev-jupyter:latest`
- `deepiri-dev-platform-analytics-service:latest`

### Backend Team
- All `deepiri-dev-*` microservices (except frontend, cyrex, jupyter)

### Frontend Team
- `deepiri-dev-frontend:latest`
- `deepiri-dev-api-gateway:latest`
- `deepiri-dev-realtime-gateway:latest`
- All backend services (for integration)

### Infrastructure Team
- All services

### QA Team
- All services

### Platform Engineers
- All services

## Quick Reference

```bash
# Setup
eval $(minikube docker-env)

# Build (choose your team's config)
skaffold build -f skaffold-<team>-team.yaml

# Tag with :latest
./scripts/tag-skaffold-to-latest.sh

# Run
docker compose -f docker-compose.dev.yml up -d
```

