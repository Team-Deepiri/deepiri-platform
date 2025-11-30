# Service Communication 
## This document also includes (what minimal services you need to run for your role)

## 1. Service Communication Architecture

### Communication Flow   

 ((MAYBE SYSTEMS ARCHITECTS CAN IMPLEMENT A BETTER ARCHITECTURE FOR THE MICROSERVICE COMMUNICATIONS))

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Frontend   │  │  Mobile App  │  │  External    │           │
│  │  (React)     │  │   (Future)   │  │   APIs       │           │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │
└─────────┼─────────────────┼─────────────────┼───────────────────┘
          │                 │                 │
          │  HTTP/REST      │  HTTP/REST      │  HTTP/REST
          │  WebSocket      │  WebSocket      │  WebSocket
          │                 │                 │
          └─────────────────┴─────────────────┘
                            │        
                  ┌─────────▼─────────┐
                  │   API Gateway     │  Port 5100 (5000 internally) 
                  │  (Entry Point)    │
                  │  - Auth           │
                  │  - Rate Limiting  │
                  │  - Routing        │
                  └─────────┬─────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌───────▼────────┐
│  Auth Service  │  │ Task Service    │ │ Challenge      │
│  Port 5001     │  │ Port 5002       │ │ Service        │
│                │  │                 │ │ Port 5007      │
│ - User Auth    │  │ - Task CRUD     │ │                │
│ - Profiles     │  │ - Dependencies  │ │ - Challenge    │
│ - OAuth        │  │ - Versioning    │ │   Generation   │
└───────┬────────┘  └───────┬────────┘  └───────┬────────┘
        │                   │                   │
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌───────▼────────┐
│ Engagement     │  │ Analytics      │  │ Notification   │
│ Service        │  │ Service        │  │ Service        │
│ Port 5003      │  │ Port 5004      │  │ Port 5005      │
│                │  │                │  │                │
│ - Points/XP    │  │ - Performance  │  │ - Push Notif   │
│ - Badges       │  │ - Insights     │  │ - Real-time    │
│ - Leaderboard  │  │ - Predictions  │  │ - History      │
└───────┬────────┘  └───────┬────────┘  └───────┬────────┘
        │                   │                   │
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌───────▼───────┐
│ External       │  │ Realtime       │  │ Cyrex AI      │
│ Bridge         │  │ Gateway        │  │ Service       │
│ Port 5006      │  │ Port 5008      │  │ Port 8000     │
│                │  │                │  │               │
│ - GitHub       │  │ - WebSocket    │  │ - Challenge   │
│ - Notion       │  │ - Real-time    │  │   Generation  │
│ - Trello       │  │ - Multiplayer  │  │ - Task Parse  │
│ - OAuth        │  │ - Collaboration│  │ - AI Models   │
└────────────────┘  └────────────────┘  └───────────────┘
```

### Communication Patterns

#### 1. **API Gateway Pattern (Primary)**
All external requests go through the API Gateway:
- **Frontend** → `http://localhost:5100/api/*` → API Gateway → Microservices
- **Routing Rules**:
  ```
  /api/users/*          → auth-service:5001
  /api/tasks/*          → task-orchestrator:5002
  /api/gamification/*   → engagement-service:5003
  /api/analytics/*      → platform-analytics-service:5004
  /api/notifications/*  → notification-service:5005
  /api/integrations/*   → external-bridge-service:5006
  /api/challenges/*     → challenge-service:5007
  /api/agent/*          → cyrex:8000
  ```

#### 2. **Service-to-Service Communication**
Services communicate directly via HTTP:
- **Challenge Service** → `http://cyrex:8000/agent/generate` (AI challenge generation)
- **Analytics Service** → `http://auth-service:5001/api/users` (user data)
- **Notification Service** → `http://engagement-service:5003/api/points` (points updates)

#### 3. **WebSocket Communication**
Real-time updates via WebSocket Gateway:
- **Frontend** → `ws://localhost:5100` → API Gateway → Realtime Gateway (Port 5008)
- Used for: Live notifications, multiplayer challenges, collaboration

#### 4. **Database Communication**
All services connect to shared databases:
- **MongoDB** (Port 27017): Primary data store for all services
- **Redis** (Port 6379): Caching, session management (Engagement, Notification)
- **InfluxDB** (Port 8086): Time-series analytics (Auth, Analytics)

### Service Dependencies

```
API Gateway
  ├── Depends on: All microservices
  └── Routes to: All microservices

Challenge Service
  ├── Depends on: Cyrex AI Service (for challenge generation)
  └── Uses: MongoDB (challenge data)

Engagement Service
  ├── Depends on: Redis (caching, leaderboards)
  └── Uses: MongoDB (user points, badges)

Analytics Service
  ├── Depends on: InfluxDB (time-series data)
  └── Uses: MongoDB (aggregated analytics)

Notification Service
  ├── Depends on: Redis (notification queue)
  └── Uses: MongoDB (notification history)

All Services
  ├── MongoDB (primary database)
  ├── Redis (caching, queues)
  └── InfluxDB (time-series)
```

---

## 2. Team-Specific Service Requirements

###  AI Team

**Primary Services:**
- ✅ **Cyrex AI Service** (Port 8000) - Main AI/ML service
- ✅ **Jupyter** - Experimentation and model development
- ✅ **MLflow** (Port 5000) - Experiment tracking and model registry
- ✅ **Challenge Service** (Port 5007) - Integration testing with AI

**Infrastructure Needed:**
- ✅ **MongoDB** - Training data, model metadata
- ✅ **InfluxDB** - Model performance metrics, training metrics
- ✅ **Redis** (optional) - Caching model predictions

**What They Work On:**
- `diri-cyrex/` - Python AI service
  - Challenge generation algorithms
  - Task understanding models
  - RL models for personalization
  - Multimodal AI integration
- `platform-services/backend/deepiri-challenge-service/` - Challenge service integration

**Start Command:**
```bash
docker compose -f docker-compose.dev.yml up -d \
  mongodb influxdb redis cyrex jupyter mlflow challenge-service
```

---

### ML Team

**Primary Services:**
- ✅ **Cyrex AI Service** (Port 8000) - Model inference
- ✅ **Jupyter** - Data analysis and model training
- ✅ **MLflow** - Model versioning and tracking
- ✅ **Analytics Service** (Port 5004) - Feature engineering data

**Infrastructure Needed:**
- ✅ **MongoDB** - Training datasets
- ✅ **InfluxDB** - Time-series features, model metrics
- ✅ **Redis** - Feature caching

**What They Work On:**
- `diri-cyrex/app/services/` - ML model implementations
- `diri-cyrex/train/` - Training pipelines
- `platform-services/backend/deepiri-platform-analytics-service/` - Analytics features

**Start Command:**
```bash
docker compose -f docker-compose.dev.yml up -d \
  mongodb influxdb redis cyrex jupyter mlflow platform-analytics-service
```

---

### Infrastructure Team

**Primary Services:**
- ✅ **All Infrastructure Services**
  - MongoDB (Port 27017)
  - Redis (Port 6379)
  - InfluxDB (Port 8086)
  - Mongo Express (Port 8081) - DB admin UI
- ✅ **API Gateway** (Port 5100) - Routing and load balancing
- ✅ **All Microservices** - For monitoring and scaling

**Infrastructure Needed:**
- ✅ **All databases** - Setup, backup, monitoring
- ✅ **Kubernetes/Minikube** - Orchestration
- ✅ **Monitoring tools** - Prometheus, Grafana (future)

**What They Work On:**
- `ops/k8s/` - Kubernetes manifests
- `docker-compose.*.yml` - Service orchestration
- `skaffold/*.yaml` - Build and deployment configs
- Infrastructure monitoring and scaling

**Start Command:**
```bash
# Start all infrastructure
docker compose -f docker-compose.dev.yml up -d \
  mongodb redis influxdb mongo-express

# Or start everything
docker compose -f docker-compose.dev.yml up -d
```

---

### Backend Team
**Primary Services:**
- ✅ **API Gateway** (Port 5100) - Entry point
- ✅ **Auth Service** (Port 5001) - Authentication
- ✅ **Task Orchestrator** (Port 5002) - Task management
- ✅ **Engagement Service** (Port 5003) - Gamification
- ✅ **Analytics Service** (Port 5004) - Analytics
- ✅ **Notification Service** (Port 5005) - Notifications
- ✅ **External Bridge Service** (Port 5006) - Integrations
- ✅ **Challenge Service** (Port 5007) - Challenges
- ✅ **Realtime Gateway** (Port 5008) - WebSocket

**Infrastructure Needed:**
- ✅ **MongoDB** - All services use MongoDB
- ✅ **Redis** - Engagement and Notification services
- ✅ **InfluxDB** - Auth and Analytics services

**What They Work On:**
- `platform-services/backend/*/` - All microservices
- `deepiri-core-api/` - Legacy monolith (being migrated)
- API Gateway routing logic
- Service-to-service communication

**Start Command:**
```bash
# Start all backend services
# Use team-specific compose file for isolated environment
docker compose -f docker-compose.backend-team.yml up -d \
  frontend-dev api-gateway auth-service task-orchestrator \
  engagement-service platform-analytics-service \
  notification-service external-bridge-service \
  challenge-service realtime-gateway
# Infrastructure (mongodb, redis, influxdb, mongo-express) starts automatically
```

---

###  Frontend Team

**Primary Services:**
- ✅ **Frontend Service** (Port 5173) - React application
- ✅ **Realtime Gateway** (Port 5008) - WebSocket for real-time features

**Infrastructure Needed:**
- ✅ **API Gateway** (Port 5100) - Routes all API calls from frontend
- ✅ **All Backend Services** - For API calls (auth-service, task-orchestrator, engagement-service, platform-analytics-service, notification-service, external-bridge-service, challenge-service, realtime-gateway)
- ✅ **MongoDB, Redis, InfluxDB** - Database infrastructure

**What They Work On:**
- `deepiri-web-frontend/` - React frontend
- API integration (`src/services/`)
- WebSocket integration (`src/services/multiplayerService.ts`)
- UI/UX components

**Start Command:**
```bash
# Start frontend + all backend services needed by api-gateway
# Note: Frontend needs api-gateway to route API calls, and api-gateway depends on all these services
docker compose -f docker-compose.frontend-team.yml up -d \
  frontend-dev api-gateway auth-service task-orchestrator \
  engagement-service platform-analytics-service \
  notification-service external-bridge-service \
  challenge-service realtime-gateway
```

---

###  Platform Engineers (Specific Group)

**Primary Services:**
- ✅ **API Gateway** - Platform routing and policies
- ✅ **All Microservices** - Platform standards and tooling
- ✅ **Infrastructure Services** - Platform infrastructure

**Infrastructure Needed:**
- ✅ **All services** - For platform tooling development
- ✅ **Kubernetes** - Platform orchestration
- ✅ **CI/CD pipelines** - Platform automation

**What They Work On:**
- Platform standards and best practices
- Service mesh and observability
- CI/CD pipelines
- Developer tooling
- Service templates and scaffolding
- Cross-cutting concerns (logging, monitoring, tracing)

**Start Command:**
```bash
# Start everything for platform development
docker compose -f docker-compose.dev.yml up -d
```

---

### QA Engineers

**Primary Services:**
- ✅ **All Services** - End-to-end testing
- ✅ **Frontend** - UI testing
- ✅ **API Gateway** - API testing
- ✅ **All Microservices** - Integration testing

**Infrastructure Needed:**
- ✅ **All databases** - Test data setup
- ✅ **All services** - Full stack testing

**What They Work On:**
- End-to-end test suites
- Integration tests
- API testing
- Performance testing
- Load testing

**Start Command:**
```bash
# Start everything for QA testing
docker compose -f docker-compose.dev.yml up -d
```

---

## Quick Reference: Service Ports

| Service | Port | Team |
|---------|------|------|
| API Gateway | 5100 | Backend, Frontend, Platform, QA |
| Auth Service | 5001 | Backend, QA |
| Task Orchestrator | 5002 | Backend, QA |
| Engagement Service | 5003 | Backend, QA |
| Analytics Service | 5004 | Backend, ML, QA |
| Notification Service | 5005 | Backend, QA |
| External Bridge | 5006 | Backend, QA |
| Challenge Service | 5007 | Backend, AI, QA |
| Realtime Gateway | 5008 | Backend, Frontend, QA |
| Cyrex AI | 8000 | AI, ML, QA |
| Frontend | 5173 | Frontend, QA |
| MongoDB | 27017 | Infrastructure, All Teams |
| Redis | 6379 | Infrastructure, Backend |
| InfluxDB | 8086 | Infrastructure, Backend, ML, AI |
| MLflow | 5000 | AI, ML |
| Jupyter | 8888 | AI, ML |

---

## Communication Protocols

### HTTP/REST
- **Primary**: All service-to-service communication
- **Protocol**: HTTP/1.1, HTTP/2
- **Format**: JSON
- **Authentication**: JWT tokens (via Auth Service)

### WebSocket
- **Primary**: Real-time features
- **Protocol**: WebSocket (via Socket.IO)
- **Use Cases**: 
  - Live notifications
  - Multiplayer challenges
  - Real-time collaboration
  - Live updates

### gRPC (Future)
- **Planned**: High-performance service-to-service communication
- **Use Cases**: Internal service communication

---

## Data Flow Examples

### Example 1: User Creates a Task
```
Frontend → API Gateway (5100)
  → Task Orchestrator (5002)
    → MongoDB (stores task)
    → Engagement Service (5003) [async]
      → Updates user XP
      → Redis (leaderboard cache)
    → Notification Service (5005) [async]
      → Sends notification
      → Realtime Gateway (5008)
        → WebSocket to Frontend
```

### Example 2: Generate Challenge
```
Frontend → API Gateway (5100)
  → Challenge Service (5007)
    → Cyrex AI Service (8000)
      → Generates challenge
      → Returns challenge data
    → Challenge Service
      → Stores in MongoDB
      → Notifies Engagement Service (5003)
        → Updates challenge stats
      → Notification Service (5005)
        → Sends challenge notification
```

### Example 3: Real-time Collaboration
```
Frontend → Realtime Gateway (5008) [WebSocket]
  → Broadcasts to other users
  → Updates MongoDB (collaboration state)
  → Notifies all connected clients
```

---

## Service Health Checks

All services expose `/health` endpoints:
```bash
curl http://localhost:5100/health  # API Gateway
curl http://localhost:5001/health  # Auth Service
curl http://localhost:5002/health # Task Orchestrator
# ... etc
```

