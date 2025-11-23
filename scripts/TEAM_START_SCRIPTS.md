# Team Start Scripts

Simple shell scripts that use `docker-compose.dev.yml` to build and start only the services each team needs.

## Usage

All scripts are in the `scripts/` directory. Run from the `deepiri/` directory:

```bash
# From deepiri/ directory
./scripts/start-ai-team.sh
./scripts/start-ml-team.sh
./scripts/start-backend-team.sh
./scripts/start-frontend-team.sh
./scripts/start-infrastructure-team.sh
./scripts/start-platform-engineers.sh
./scripts/start-qa-team.sh
```

## What Each Script Does

### AI Team (`start-ai-team.sh`)
- **Builds**: cyrex, jupyter, challenge-service
- **Starts**: mongodb, influxdb, redis, etcd, minio, milvus, cyrex, jupyter, mlflow, challenge-service
- **Ports**: 
  - Cyrex: 8000
  - Jupyter: 8888
  - MLflow: 5500
  - Challenge Service: 5007

### ML Team (`start-ml-team.sh`)
- **Builds**: cyrex, jupyter, platform-analytics-service
- **Starts**: mongodb, influxdb, redis, cyrex, jupyter, mlflow, platform-analytics-service
- **Ports**:
  - Cyrex: 8000
  - Jupyter: 8888
  - MLflow: 5500
  - Analytics Service: 5004

### Backend Team (`start-backend-team.sh`)
- **Builds**: All backend microservices
- **Starts**: mongodb, redis, influxdb + all backend services
- **Ports**: 5000-5008 (all backend services)

### Frontend Team (`start-frontend-team.sh`)
- **Builds**: frontend + all backend services
- **Starts**: mongodb, redis, influxdb + all backend + frontend
- **Ports**:
  - Frontend: 5173
  - API Gateway: 5000
  - All backend services: 5001-5008

### Infrastructure Team (`start-infrastructure-team.sh`)
- **Builds**: Everything
- **Starts**: Everything
- **Ports**: All services

### Platform Engineers (`start-platform-engineers.sh`)
- **Builds**: Everything
- **Starts**: Everything
- **Ports**: All services

### QA Team (`start-qa-team.sh`)
- **Builds**: Everything
- **Starts**: Everything
- **Ports**: All services

## How It Works

Each script:
1. Changes to the `deepiri/` directory (repo root)
2. Builds only the services that team needs (using `docker compose build`)
3. Starts all required services (using `docker compose up -d`)
4. Shows helpful URLs for accessing services

All scripts use `docker-compose.dev.yml` - no need for separate compose files!

## Stopping Services

To stop services:

```bash
# Stop specific services
docker compose -f docker-compose.dev.yml stop <service-name>

# Stop all services
docker compose -f docker-compose.dev.yml down

# Stop and remove volumes
docker compose -f docker-compose.dev.yml down -v
```

## Rebuilding After Code Changes

If you change code and need to rebuild:

```bash
# Rebuild specific service
docker compose -f docker-compose.dev.yml build <service-name>

# Rebuild and restart
docker compose -f docker-compose.dev.yml up -d --build <service-name>
```

Or just run the team script again - it will rebuild and restart.

