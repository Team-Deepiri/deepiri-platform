# Deepiri Python Environment Startup Scripts

Python-based Docker management scripts for starting services based on team roles. These scripts replace docker-compose for role-specific service orchestration.

## Installation

1. Install Python dependencies:
```bash
cd py_environment_startup_scripts
pip install -r requirements.txt
```

2. Ensure Docker is running on your system.

3. Make sure you have a `.env` file in the project root with necessary environment variables.

## Available Scripts

### Team-Specific Scripts

#### 1. AI Team (`start_ai_team.py`)
Starts services needed by the AI team:
- **PyAgent** (AI Service) - Port 8000
- **MLflow** - Port 5001
- **Jupyter Notebook** - Port 8888
- **Challenge Service** - Port 5007
- **MongoDB** - Port 27017
- **Redis** - Port 6379

**Usage:**
```bash
python start_ai_team.py
```

#### 2. Frontend Team (`start_frontend_team.py`)
Starts services needed by frontend developers:
- **Frontend** (Vite HMR) - Port 5173
- **API Gateway** - Port 5000
- **MongoDB** - Port 27017
- **Mongo Express** - Port 8081
- **Redis** - Port 6379

**Usage:**
```bash
python start_frontend_team.py
```

#### 3. Backend Team (`start_backend_team.py`)
Starts all microservices and infrastructure:
- **API Gateway** - Port 5000
- **User Service** - Port 5001
- **Task Service** - Port 5002
- **Gamification Service** - Port 5003
- **Analytics Service** - Port 5004
- **Notification Service** - Port 5005
- **Integration Service** - Port 5006
- **WebSocket Service** - Port 5008
- **MongoDB** - Port 27017
- **Mongo Express** - Port 8081
- **Redis** - Port 6379
- **InfluxDB** - Port 8086

**Usage:**
```bash
python start_backend_team.py
```

#### 4. ML Team (`start_ml_team.py`)
Starts services for ML engineers:
- **PyAgent** (AI Service) - Port 8000
- **MLflow** - Port 5001
- **Jupyter Notebook** - Port 8888
- **MongoDB** - Port 27017
- **Redis** - Port 6379
- **InfluxDB** - Port 8086

**Usage:**
```bash
python start_ml_team.py
```

#### 5. AI Research Team (`start_ai_research_team.py`)
Starts services for AI researchers:
- **Jupyter Notebook** - Port 8888
- **MLflow** - Port 5001
- **PyAgent** (AI Service) - Port 8000
- **MongoDB** - Port 27017

**Usage:**
```bash
python start_ai_research_team.py
```

#### 6. ML Ops Team (`start_mlops_team.py`)
Starts services for ML Ops engineers:
- **MLflow** - Port 5001
- **Prometheus** - Port 9090
- **Grafana** - Port 3001
- **ML Ops Service** - Port 8001
- **PyAgent** - Port 8000

**Usage:**
```bash
python start_mlops_team.py
```

#### 7. QA Testing Team (`start_qa_team.py`)
Starts all services needed for QA testing:
- **Frontend** - Port 5173
- **API Gateway** - Port 5000
- **All Microservices** - Ports 5001-5008
- **PyAgent** (AI Service) - Port 8000
- **MongoDB** - Port 27017
- **Mongo Express** - Port 8081
- **Redis** - Port 6379
- **InfluxDB** - Port 8086

**Usage:**
```bash
python start_qa_team.py
```

#### 8. Infrastructure Team (`start_infrastructure_team.py`)
Starts infrastructure monitoring and management tools:
- **Prometheus** - Port 9090
- **Grafana** - Port 3001
- **MLflow** - Port 5001
- **All Services** (for monitoring) - Full stack
- **MongoDB** - Port 27017
- **Mongo Express** - Port 8081
- **Redis** - Port 6379
- **InfluxDB** - Port 8086

**Usage:**
```bash
python start_infrastructure_team.py
```

#### 9. All Services (`start_all_services.py`)
Starts the complete platform with all services:
- All microservices
- Frontend
- AI services
- Databases
- Monitoring tools

**Usage:**
```bash
python start_all_services.py
```

## Stopping Services

To stop services, you can:
1. Use Docker directly:
```bash
docker stop $(docker ps -q --filter "name=deepiri")
```

2. Or create stop scripts (similar to start scripts) that call:
```python
manager.stop_services(container_names)
```

## Environment Variables

Ensure your `.env` file in the project root contains:

```env
# Database
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=password
MONGO_DB=deepiri
REDIS_PASSWORD=redispassword

# AI Services
OPENAI_API_KEY=your_key_here
OPENAI_MODEL=gpt-4o-mini
PYAGENT_API_KEY=change-me
WANDB_API_KEY=your_key_here

# InfluxDB
INFLUXDB_USER=admin
INFLUXDB_PASSWORD=adminpassword
INFLUXDB_ORG=deepiri
INFLUXDB_BUCKET=analytics
INFLUXDB_TOKEN=your-influxdb-token

# External APIs (optional)
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
NOTION_CLIENT_ID=...
NOTION_CLIENT_SECRET=...

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin
```

## Architecture

- **docker_manager.py**: Core Docker management utility
- **start_*.py**: Role-specific startup scripts
- All scripts use the Docker SDK to manage containers programmatically

## Troubleshooting

1. **Docker not running**: Ensure Docker Desktop (or Docker daemon) is running
2. **Port conflicts**: Check if ports are already in use and stop conflicting services
3. **Build failures**: Ensure Dockerfiles exist in the specified paths
4. **Network issues**: Scripts automatically create the `deepiri-network` if it doesn't exist

## Notes

- Services are started with `restart_policy: unless-stopped`
- Volumes are created automatically for data persistence
- Services wait for dependencies before starting (configurable delays)
- All containers are prefixed with `deepiri-` for easy identification

