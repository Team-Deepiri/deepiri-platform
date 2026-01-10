# Deepiri Quick Reference Guide

**Last Updated:** 2025-12-01

## All Service URLs

### Frontend & Visual Interfaces

| Service | Type | URL | Port | Description |
|---------|------|-----|------|-------------|
| Frontend | Visual | http://localhost:5173/ | 5173 | Main web application (Vite HMR) |
| Cyrex UI | Visual | http://localhost:5175/ | 5175 | AI/ML interface |
| pgAdmin | Visual | http://localhost:5050/ | 5050 | PostgreSQL admin UI |
| Adminer | Visual | http://localhost:8080/ | 8080 | Lightweight database viewer |
| InfluxDB UI | Visual | http://localhost:8086/ | 8086 | Time-series database UI |
| MLflow UI | Visual | http://localhost:5500/ | 5500 | ML experiment tracking |
| Jupyter | Visual | http://localhost:8888/ | 8888 | Jupyter notebooks |
| MinIO Console | Visual | http://localhost:9001/ | 9001 | Object storage console |

### API Services

| Service | Type | URL | Port | Description |
|---------|------|-----|------|-------------|
| API Gateway | API | http://localhost:5100/ | 5100 | Main entry point (routes to all services) |
| Auth Service | API | http://localhost:5001/ | 5001 | Authentication & authorization |
| Task Orchestrator | API | http://localhost:5002/ | 5002 | Task management |
| Engagement Service | API | http://localhost:5003/ | 5003 | Gamification (momentum, streaks, boosts) |
| Platform Analytics | API | http://localhost:5004/ | 5004 | Analytics & metrics |
| Notification Service | API | http://localhost:5005/ | 5005 | Notifications |
| External Bridge | API | http://localhost:5006/ | 5006 | External integrations |
| Challenge Service | API | http://localhost:5007/ | 5007 | Challenge generation |
| Realtime Gateway | API | http://localhost:5008/ | 5008 | WebSocket connections |
| Cyrex AI | API | http://localhost:8000/ | 8000 | AI/ML service |

### Databases & Storage

| Service | Type | URL | Port | Description |
|---------|------|-----|------|-------------|
| PostgreSQL | Database | postgresql://localhost:5432 | 5432 | Primary database (users, tasks, quests) |
| Redis | Cache | redis://localhost:6380 | 6380 | Caching & session storage |
| InfluxDB | Database | http://localhost:8086 | 8086 | Time-series analytics |
| Milvus | Database | localhost:19530 | 19530 | Vector database (RAG) |
| MinIO | Storage | http://localhost:9000 | 9000 | Object storage (S3-compatible) |
| etcd | Database | localhost:2379 | 2379 | Key-value store (Milvus metadata) |

---

## 📋 Quick Commands

### Start All Services
```bash
cd deepiri
docker compose -f docker-compose.dev.yml up -d
```

### Stop All Services
```bash
docker compose -f docker-compose.dev.yml down
```

### View Logs
```bash
# All services
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f <service-name>
```

### Check Service Status
```bash
docker compose -f docker-compose.dev.yml ps
```

### Restart a Service
```bash
docker compose -f docker-compose.dev.yml restart <service-name>
```

### Rebuild a Service
```bash
docker compose -f docker-compose.dev.yml up -d --build <service-name>
```

---

## 🔍 Health Checks

### Test All API Services
```bash
# PowerShell
5100, 5001, 5002, 5003, 5004, 5005, 5006, 5007, 5008, 8000 | ForEach-Object {
  Write-Host "Testing port $_..."
  try {
    $response = Invoke-WebRequest -Uri "http://localhost:$_/health" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "✓ Port $_: OK" -ForegroundColor Green
  } catch {
    Write-Host "✗ Port $_: Failed" -ForegroundColor Red
  }
}

# Bash
for port in 5100 5001 5002 5003 5004 5005 5006 5007 5008 8000; do
  echo "Testing port $port..."
  curl -s http://localhost:$port/health && echo "✓ OK" || echo "✗ Failed"
done
```

---

## 🗄️ Database Access

### PostgreSQL
```bash
# Connection string
postgresql://deepiri:deepiripassword@localhost:5432/deepiri

# Using psql
psql -h localhost -p 5432 -U deepiri -d deepiri
```

### Redis
```bash
# Connection string
redis://localhost:6380

# Using redis-cli
redis-cli -h localhost -p 6380 -a redispassword
```

### InfluxDB
- **URL:** http://localhost:8086
- **Default Username:** admin
- **Default Password:** adminpassword
- **Organization:** deepiri
- **Bucket:** analytics

---

## 🛠️ Development Tools

### Access Services

| Tool | URL | Credentials |
|------|-----|-------------|
| pgAdmin | http://localhost:5050 | admin@deepiri.com / admin |
| Adminer | http://localhost:8080 | System: PostgreSQL<br>Server: postgres<br>Username: deepiri<br>Password: deepiripassword<br>Database: deepiri |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |
| MLflow | http://localhost:5500 | No auth required |
| Jupyter | http://localhost:8888 | No token required |

---

## 📊 Service Dependencies

### Core Infrastructure
- **PostgreSQL** → All backend services
- **Redis** → Engagement Service, Notification Service
- **InfluxDB** → Auth Service, Platform Analytics, Cyrex

### AI/ML Stack
- **Milvus** → Cyrex (vector search)
- **MinIO** → Milvus (object storage)
- **etcd** → Milvus (metadata)
- **MLflow** → Cyrex (experiment tracking)

### Service Dependencies
- **API Gateway** → All microservices
- **Frontend** → API Gateway
- **Challenge Service** → Cyrex
- **All Services** → PostgreSQL

---

## 🔐 Default Credentials

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| PostgreSQL | deepiri | deepiripassword | Set via `POSTGRES_PASSWORD` |
| Redis | - | redispassword | Set via `REDIS_PASSWORD` |
| pgAdmin | admin@deepiri.com | admin | Set via `PGADMIN_PASSWORD` |
| InfluxDB | admin | adminpassword | Set via `INFLUXDB_PASSWORD` |
| MinIO | minioadmin | minioadmin | Set via `MINIO_ROOT_PASSWORD` |

**⚠️ Change these in production!**

---

## 📝 Notes

- **API Gateway** uses port **5100** externally (to avoid macOS AirPlay conflict on 5000)
- **Redis** uses port **6380** externally (to avoid system Redis on 6379)
- All services run on the `deepiri-dev-network` Docker network
- Services use environment variables from `.env` file or `ops/k8s/configmaps/`
- Development mode uses volume mounts for hot-reload

---

## 🔗 Related Documentation

- `docs/SERVICES_OVERVIEW.md` - Detailed service architecture
- `docs/HOW_TO_BUILD.md` - Build instructions
- `SERVICE_COMMUNICATION_AND_TEAMS.md` - Team-specific service lists
- `GETTING_STARTED.md` - Onboarding guide
