# Microservices Architecture - Complete Setup

## Overview

Deepiri is now fully architected as a microservices system. All services run independently and communicate through the API Gateway.

## Service Architecture

```
┌─────────────────┐
│  API Gateway    │  Port 5000
│  (Entry Point)  │
└────────┬────────┘
         │
    ┌────┴────┬──────────────┬──────────────┬──────────────┐
    │         │              │              │              │
┌───▼───┐ ┌──▼───┐ ┌────────▼──┐ ┌─────────▼──┐ ┌─────────▼──┐
│ User  │ │ Task │ │Gamification│ │ Analytics │ │Challenge  │
│ :5001 │ │:5002 │ │   :5003    │ │   :5004   │ │   :5007   │
└───────┘ └──────┘ └────────────┘ └───────────┘ └───────────┘
    │         │              │              │              │
┌───▼───┐ ┌──▼───┐ ┌────────▼──┐
│Notif. │ │Integ.│ │ WebSocket │
│ :5005 │ │:5006 │ │   :5008   │
└───────┘ └──────┘ └───────────┘
    │
┌───▼────┐
│Cyrex │  Port 8000 (AI Service)
│(Python)│
└────────┘
```

## Services

### 1. API Gateway (Port 5000)
- **Location**: `platform-services/backend/deepiri-api-gateway/`
- **Purpose**: Routes all requests to appropriate microservices
- **Endpoints**:
  - `/api/users/*` → User Service
  - `/api/tasks/*` → Task Service
  - `/api/gamification/*` → Gamification Service
  - `/api/analytics/*` → Analytics Service
  - `/api/notifications/*` → Notification Service
  - `/api/integrations/*` → Integration Service
  - `/api/challenges/*` → Challenge Service
  - `/api/agent/*` → Python AI Service

### 2. User Service (Port 5001)
- **Location**: `platform-services/backend/deepiri-auth-service/`
- **Features**: OAuth 2.0, Skill Trees, Social Graph, Time-Series
- **Endpoints**: `/oauth/*`, `/skill-tree/*`, `/social/*`, `/time-series/*`

### 3. Task Service (Port 5002)
- **Location**: `platform-services/backend/deepiri-task-orchestrator/`
- **Features**: Task CRUD, Versioning, Dependency Graphs
- **Endpoints**: `/tasks/*`, `/dependencies/*`

### 4. Gamification Service (Port 5003)
- **Location**: `platform-services/backend/deepiri-engagement-service/`
- **Features**: Multi-Currency, Badges, ELO Leaderboards
- **Endpoints**: `/currency/*`, `/badges/*`, `/leaderboard/*`

### 5. Analytics Service (Port 5004)
- **Location**: `platform-services/backend/deepiri-platform-analytics-service/`
- **Features**: Time-Series Analytics, Behavioral Clustering, Predictive Modeling
- **Endpoints**: `/time-series/*`, `/clustering/*`, `/predictive/*`

### 6. Notification Service (Port 5005)
- **Location**: `platform-services/backend/deepiri-notification-service/`
- **Features**: WebSocket Server, Push Notifications (FCM/APNS)
- **Endpoints**: `/push/*`, `/websocket/*`

### 7. Integration Service (Port 5006)
- **Location**: `platform-services/backend/deepiri-external-bridge-service/`
- **Features**: OAuth Flows, Webhook Processing
- **Endpoints**: `/webhooks/*`, `/oauth/*`

### 8. Challenge Service (Port 5007)
- **Location**: `platform-services/backend/deepiri-challenge-service/`
- **Features**: Challenge Generation (calls AI service)
- **Endpoints**: `/generate`

### 9. WebSocket Service (Port 5008)
- **Location**: `platform-services/backend/deepiri-realtime-gateway/`
- **Features**: Real-time WebSocket connections
- **Protocol**: WebSocket (Socket.IO)

### 10. Python AI Service (Port 8000)
- **Location**: `diri-cyrex/`
- **Features**: AI/ML inference, Challenge generation, Task understanding
- **Endpoints**: `/agent/*`

## Running the Services

### Development (Docker Compose)

```bash
# Start all services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop all services
docker-compose -f docker-compose.dev.yml down

# Rebuild services
docker-compose -f docker-compose.dev.yml build --no-cache
```

### Individual Service Development

Each service can be run independently:

```bash
# User Service
cd platform-services/backend/deepiri-auth-service
npm install
npm start  # or npm run dev

# Task Service
cd platform-services/backend/deepiri-task-orchestrator
npm install
npm start

# ... etc for each service
```

## Service Communication

### Internal Communication
Services communicate via HTTP REST APIs using service names as hostnames:
- `http://auth-service:5001`
- `http://task-orchestrator:5002`
- etc.

### External Communication
All external requests go through the API Gateway:
- deepiri-web-frontend → `http://api-gateway:5000/api/*`
- External APIs → `http://api-gateway:5000/api/*`

### WebSocket
WebSocket connections go directly to the WebSocket Service:
- `ws://realtime-gateway:5008`

## Environment Variables

Each service requires specific environment variables. See `.env.example` files in each service directory.

### Common Variables
- `MONGO_URI` - MongoDB connection string
- `REDIS_HOST` - Redis host (for services that use it)
- `NODE_ENV` - Environment (development/production)
- `PORT` - Service port

### Service-Specific Variables
- **User Service**: `INFLUXDB_URL`, `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`
- **Analytics Service**: `INFLUXDB_URL`, `INFLUXDB_TOKEN`
- **Notification Service**: `FCM_SERVER_KEY`, `APNS_KEY_ID`
- **Integration Service**: `GITHUB_CLIENT_ID`, `NOTION_CLIENT_ID`, etc.
- **Challenge Service**: `CYREX_URL`
- **Python AI Service**: `OPENAI_API_KEY`, `MLFLOW_TRACKING_URI`, etc.

## Health Checks

All services expose a `/health` endpoint:

```bash
# Check API Gateway
curl http://localhost:5000/health

# Check User Service
curl http://localhost:5001/health

# Check Task Service
curl http://localhost:5002/health

# ... etc
```

## Service Dependencies

```
API Gateway
  ├── User Service
  ├── Task Service
  ├── Gamification Service
  ├── Analytics Service
  ├── Notification Service
  ├── Integration Service
  ├── Challenge Service
  │   └── Python AI Service
  └── WebSocket Service

All Services
  ├── MongoDB
  ├── Redis (Gamification, Notification)
  └── InfluxDB (User, Analytics)
```

## Database Connections

- **MongoDB**: All Node.js services connect to MongoDB
- **Redis**: Used by Gamification and Notification services
- **InfluxDB**: Used by User and Analytics services for time-series data

## API Gateway Routing

The API Gateway uses `http-proxy-middleware` to route requests:

```javascript
/api/users/* → http://auth-service:5001/*
/api/tasks/* → http://task-orchestrator:5002/tasks/*
/api/gamification/* → http://gamification-service:5003/*
/api/analytics/* → http://analytics-service:5004/*
/api/notifications/* → http://notification-service:5005/*
/api/integrations/* → http://external-bridge-service:5006/*
/api/challenges/* → http://challenge-service:5007/*
/api/agent/* → http://cyrex:8000/agent/*
```

## Development Workflow

1. **Start Infrastructure**:
   ```bash
   docker-compose -f docker-compose.dev.yml up mongodb redis influxdb -d
   ```

2. **Start Services** (individually or all):
   ```bash
   docker-compose -f docker-compose.dev.yml up api-gateway auth-service task-orchestrator -d
   ```

3. **Start deepiri-web-frontend**:
   ```bash
   docker-compose -f docker-compose.dev.yml up deepiri-web-frontend-dev -d
   ```

4. **View Logs**:
   ```bash
   docker-compose -f docker-compose.dev.yml logs -f [service-name]
   ```

## Testing

Each service can be tested independently:

```bash
# Test User Service
curl -X POST http://localhost:5001/oauth/register \
  -H "Content-Type: application/json" \
  -d '{"clientId": "test", "clientSecret": "secret"}'

# Test Task Service
curl http://localhost:5002/tasks

# Test API Gateway routing
curl http://localhost:5000/api/users/health
```

## Production Deployment

For production, use `docker-compose.yml` (without `-dev`):

```bash
docker-compose up -d
```

Production configuration:
- Services run in production mode
- No volume mounts (code baked into images)
- Health checks enabled
- Resource limits configured
- Logging to centralized system

## Troubleshooting

### Service Won't Start
1. Check logs: `docker-compose logs [service-name]`
2. Verify environment variables
3. Check service dependencies (MongoDB, Redis, etc.)
4. Verify port availability

### Service Communication Issues
1. Verify services are on same Docker network
2. Check service names in URLs
3. Verify API Gateway routing configuration
4. Check service health endpoints

### Database Connection Issues
1. Verify MongoDB is running: `docker-compose ps mongodb`
2. Check connection string format
3. Verify credentials
4. Check network connectivity

---

**Status**: ✅ Fully Microservices Architecture
**Last Updated**: 2024




