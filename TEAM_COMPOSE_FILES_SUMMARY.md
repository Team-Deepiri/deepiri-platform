# Team Docker Compose Files Summary

All team-specific docker-compose files have been updated to match `docker-compose.dev.yml` exactly, but only include the services each team needs according to their `start.sh` scripts.

## Files Updated

### ✅ docker-compose.ai-team.yml
- **Name**: `deepiri-ai`
- **Services**: mongodb, influxdb, redis, etcd, minio, milvus, cyrex, jupyter, mlflow, challenge-service
- **Matches**: docker-compose.dev.yml exactly for these services
- **Container names**: `deepiri-*-ai`
- **Network**: `deepiri-ai-network`
- **Volumes**: `*_ai_data`, `cyrex_ai_cache`

### ✅ docker-compose.ml-team.yml
- **Name**: `deepiri-ml`
- **Services**: mongodb, influxdb, redis, cyrex, jupyter, mlflow, platform-analytics-service
- **Matches**: docker-compose.dev.yml exactly for these services
- **Container names**: `deepiri-*-ml`
- **Network**: `deepiri-ml-network`
- **Volumes**: `*_ml_data`, `cyrex_ml_cache`

### ✅ docker-compose.backend-team.yml
- **Name**: `deepiri-backend`
- **Services**: mongodb, redis, influxdb, api-gateway, auth-service, task-orchestrator, engagement-service, platform-analytics-service, notification-service, external-bridge-service, challenge-service, realtime-gateway
- **Matches**: docker-compose.dev.yml exactly for these services
- **Container names**: `deepiri-*-backend`
- **Network**: `deepiri-backend-network`
- **Volumes**: `*_backend_data`

### ✅ docker-compose.frontend-team.yml
- **Name**: `deepiri-frontend`
- **Services**: mongodb, redis, influxdb, api-gateway, auth-service, task-orchestrator, engagement-service, platform-analytics-service, notification-service, external-bridge-service, challenge-service, realtime-gateway, frontend-dev
- **Matches**: docker-compose.dev.yml exactly for these services
- **Container names**: `deepiri-*-frontend`
- **Network**: `deepiri-frontend-network`
- **Volumes**: `*_frontend_data`

### ✅ docker-compose.infrastructure-team.yml
- **Name**: `deepiri-infrastructure`
- **Services**: ALL SERVICES (complete stack)
- **Matches**: docker-compose.dev.yml exactly (all services)
- **Container names**: `deepiri-*-infrastructure`
- **Network**: `deepiri-infrastructure-network`
- **Volumes**: `*_infrastructure_data`

### ✅ docker-compose.platform-engineers.yml
- **Name**: `deepiri-platform`
- **Services**: ALL SERVICES (complete stack)
- **Matches**: docker-compose.dev.yml exactly (all services)
- **Container names**: `deepiri-*-platform`
- **Network**: `deepiri-platform-network`
- **Volumes**: `*_platform_data`

### ✅ docker-compose.qa-team.yml
- **Name**: `deepiri-qa`
- **Services**: ALL SERVICES (complete stack)
- **Matches**: docker-compose.dev.yml exactly (all services)
- **Container names**: `deepiri-*-qa`
- **Network**: `deepiri-qa-network`
- **Volumes**: `*_qa_data`

## Key Features

1. **100% Matching**: All service definitions match `docker-compose.dev.yml` exactly
2. **Team Isolation**: Each team has separate container names, networks, and volumes
3. **Service Filtering**: Each team only includes services from their `start.sh` script
4. **Consistent Structure**: All files use the same header format and structure as `docker-compose.dev.yml`

## Usage

Each team can now use their specific compose file:

```bash
# AI Team
docker compose -f docker-compose.ai-team.yml up -d

# ML Team
docker compose -f docker-compose.ml-team.yml up -d

# Backend Team
docker compose -f docker-compose.backend-team.yml up -d

# Frontend Team
docker compose -f docker-compose.frontend-team.yml up -d

# Infrastructure Team
docker compose -f docker-compose.infrastructure-team.yml up -d

# Platform Engineers
docker compose -f docker-compose.platform-engineers.yml up -d

# QA Team
docker compose -f docker-compose.qa-team.yml up -d
```

Or use the team start scripts in `team_dev_environments/` which use `docker-compose.dev.yml` directly.

## Verification

All team compose files:
- ✅ Match `docker-compose.dev.yml` service definitions exactly
- ✅ Only include services from their respective `start.sh` scripts
- ✅ Use team-specific naming for isolation
- ✅ Have consistent header format matching `docker-compose.dev.yml`

