# Platform Services Directory

This directory contains all platform microservices for Deepiri, organized by service type.

## Directory Structure

```
platform-services/
├── backend/              # Backend microservices (Node.js)
│   ├── deepiri-api-gateway/
│   ├── deepiri-auth-service/
│   ├── deepiri-task-orchestrator/
│   ├── deepiri-challenge-service/
│   ├── deepiri-engagement-service/
│   ├── deepiri-platform-analytics-service/
│   ├── deepiri-external-bridge-service/
│   ├── deepiri-notification-service/
│   └── deepiri-realtime-gateway/
│
├── shared/              # Shared libraries and utilities
│   └── deepiri-shared-utils/
│
├── ai-ml/               # AI/ML microservices (future)
│   └── (Future AI/ML services will go here)
│
└── data/                # Data processing services (future)
    └── (Future data services will go here)
```

## Service Structure

Each service should have:
- `package.json` - Service dependencies
- `server.js` - Service entry point
- `routes/` - API routes (if applicable)
- `src/` - Source code
- `Dockerfile` - Container definition
- `.env.example` - Environment variables template
- `README.md` - Service-specific documentation

## Current Status

Services are being extracted from `deepiri-core-api/` monolith. Each service is independently deployable.

## Service Communication

Services communicate via:
- REST API (HTTP)
- Message Queue (Redis/RabbitMQ)
- WebSocket (for real-time services)

## Deployment

Each service can be deployed independently using Docker Compose or Kubernetes. See `docker-compose.dev.yml` and `docker-compose.microservices.yml` for configuration.

## Adding New Services

### Backend Services
Place new Node.js microservices in `backend/` following the naming convention: `deepiri-<service-name>-service/`

### AI/ML Services
Future Python or ML-focused services should go in `ai-ml/`

### Data Services
Future data processing, ETL, or analytics pipeline services should go in `data/`

### Shared Libraries
Shared utilities that multiple services depend on should go in `shared/`
