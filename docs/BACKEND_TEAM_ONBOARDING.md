# Backend Team Onboarding Guide

Welcome to the Deepiri Backend Team! This guide will help you get set up and start building microservices.

## Quick Reference

### Setup Minikube (for Kubernetes/Skaffold builds)
```bash
# Check if Minikube is running
minikube status

# If not running, start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### Build
```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Or use build script
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell
```

### When you DO need to build / rebuild
Only build if:
1. **Dockerfile changes**
2. **package.json/requirements.txt changes** (dependencies)
3. **First time setup**

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!

### Run all services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop all services
```bash
docker compose -f docker-compose.dev.yml down
```

### Running only services you need for your team
```bash
docker compose -f docker-compose.backend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.backend-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f auth-service
docker compose -f docker-compose.dev.yml logs -f task-orchestrator
# ... etc for all services
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Role-Specific Setup](#role-specific-setup)
4. [Development Workflow](#development-workflow)
5. [Key Resources](#key-resources)

## Prerequisites

### Required Software

- **Node.js** 18.x or higher
- **Python** 3.10+ (for AI integration)
- **Docker** and **Docker Compose**
- **MongoDB** 6.0+ (or use Docker)
- **Redis** 7.0+ (or use Docker)
- **Git**
- **VS Code** or your preferred IDE

### Required Accounts

- **GitHub Account** (for repository access)
- **MongoDB Atlas** (optional, for cloud database)
- **Firebase Account** (for authentication and push notifications)
- **API Keys** for integrations (Notion, Trello, GitHub, Google Docs)
- **OAuth Credentials** for each integration provider
- **InfluxDB Account** (optional, for time-series analytics)

### System Requirements

- **RAM:** 8GB minimum, 16GB+ recommended
- **Storage:** 20GB+ free space
- **OS:** Windows 10+, macOS 10.15+, or Linux

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd deepiri-platform
```

### 2. Set Up Git Hooks (REQUIRED)

**⚠️ IMPORTANT:** This protects the `main` and `dev` branches from accidental pushes.

```bash
./setup-hooks.sh
```

This enables local Git hooks that prevent you from pushing directly to protected branches. You'll need to use Pull Requests instead.

**Why?** See [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) for details.

### 3. Docker Setup (Required)

**For WSL2 users (Recommended): Use Docker Engine instead of Docker Desktop**

```bash
# Install Docker Engine (more reliable in WSL2 than Docker Desktop)
cd deepiri
./scripts/setup-docker-wsl2.sh

# After the script completes, restart WSL2:
# In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify Docker installation
docker --version
docker-compose --version
docker ps
```

**What the script does:**
- Installs Docker Engine, Buildx, and Compose (official Docker packages)
- Verifies Docker's official GPG key fingerprint (security check)
- Configures WSL2 for systemd
- See [QUICK-START-SCRIPTS.md](../QUICK-START-SCRIPTS.md) for manual installation steps

### 4. Environment Configuration

```bash
# Copy environment templates
cp env.example .env
cp env.example.server deepiri-core-api/.env

# Edit .env files with your configuration
```

### 5. Database Setup

**MongoDB:**
```bash
# Using Docker
docker run -d --name mongodb -p 27017:27017 mongo:6.0

# Or install locally
# macOS: brew install mongodb-community
# Ubuntu: sudo apt-get install mongodb
```

**Redis:**
```bash
# Using Docker
docker run -d --name redis -p 6379:6379 redis:7-alpine

# Or install locally
# macOS: brew install redis
# Ubuntu: sudo apt-get install redis-server
```

**InfluxDB (Optional - for time-series analytics):**
```bash
# Using Docker
docker run -d --name influxdb -p 8086:8086 \
  -e INFLUXDB_DB=analytics \
  -e INFLUXDB_ADMIN_USER=admin \
  -e INFLUXDB_ADMIN_PASSWORD=admin \
  influxdb:2.7

# Or install locally
# macOS: brew install influxdb
# Ubuntu: wget https://dl.influxdata.com/influxdb/releases/influxdb2-2.7.0-linux-amd64.tar.gz
```

### 4. Microservices Setup (Backend Team)

**Backend team needs ALL microservices for development and testing:**

```bash
# Start all microservices and infrastructure
docker-compose -f docker-compose.dev.yml up -d \
  mongodb \
  redis \
  influxdb \
  mongo-express \
  api-gateway \
  auth-service \
  task-orchestrator \
  gamification-service \
  analytics-service \
  notification-service \
  external-bridge-service \
  challenge-service \
  realtime-gateway \
  cyrex \
  mlflow

# Check service status
docker-compose -f docker-compose.dev.yml ps

# View logs for specific service
docker-compose -f docker-compose.dev.yml logs -f auth-service
docker-compose -f docker-compose.dev.yml logs -f task-orchestrator
# ... etc for any service

# View all logs
docker-compose -f docker-compose.dev.yml logs -f
```

**All Backend Services:**
- **Databases:** mongodb, redis, influxdb
- **Admin Tools:** mongo-express
- **API Gateway:** api-gateway (port 5000)
- **Core Services:** auth-service (5001), task-orchestrator (5002), gamification-service (5003)
- **Analytics:** analytics-service (5004)
- **Communication:** notification-service (5005), realtime-gateway (5008)
- **Integrations:** external-bridge-service (5006)
- **AI:** challenge-service (5007), cyrex (8000)
- **MLOps:** mlflow (5500)

**Services NOT typically needed:**
- `deepiri-web-frontend-dev` (unless testing full stack)
- `jupyter` (AI team only)

**Individual Service Development:**
```bash
# API Gateway (routes all requests)
cd platform-services/backend/deepiri-api-gateway
npm install
npm start  # Port 5000

# User Service
cd platform-services/backend/deepiri-auth-service
npm install
npm start  # Port 5001

# Task Service
cd platform-services/backend/deepiri-task-orchestrator
npm install
npm start  # Port 5002

# ... etc for each service
```

**All requests go through API Gateway at http://localhost:5000**

### 5. Stop Services (When Done)

```bash
# Stop all services
docker-compose -f docker-compose.dev.yml stop

# Or stop specific services
docker-compose -f docker-compose.dev.yml stop auth-service task-orchestrator

# Remove containers and volumes
docker-compose -f docker-compose.dev.yml down -v
```

### 6. Python AI Service Setup (for AI Integration)

```bash
cd diri-cyrex

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows

# Install dependencies
pip install -r requirements.txt

# Start FastAPI server
uvicorn app.main:app --reload --port 8000
```

Python service runs on http://localhost:8000

### 6. Verify Setup

```bash
# Test backend
curl http://localhost:5000/health

# Test Python service
curl http://localhost:8000/health
```

## Role-Specific Setup

### Backend Lead

**Additional Setup:**
```bash
# Install architecture tools
npm install -g @nestjs/cli
npm install -g typescript

# Review architecture
cat MICROSERVICES_ARCHITECTURE.md
```

**First Tasks:**
1. Review `docs/MICROSERVICES_SETUP.md` - Complete microservices guide
2. Review `docker-compose.dev.yml` - Service configuration
3. Review all services in `platform-services/backend/` directory
4. Test API Gateway routing
5. Coordinate with AI Systems Lead for Python service integration

**Key Files:**
- `docs/MICROSERVICES_SETUP.md` - Microservices architecture
- `platform-services/backend/deepiri-api-gateway/server.js` - API Gateway routing
- `platform-services/backend/*/server.js` - Individual service servers
- `docker-compose.dev.yml` - Service orchestration

---

### Backend Engineer 1 (Avatar) - External Integrations

**Additional Setup:**
```bash
# Install OAuth and webhook libraries
npm install passport passport-oauth2
npm install express-session
npm install crypto  # For webhook signature verification
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-external-bridge-service/server.js` - Service entry point
2. Review `platform-services/backend/deepiri-external-bridge-service/src/webhookService.js` - Webhook processing
3. Review `platform-services/backend/deepiri-external-bridge-service/src/index.js` - Route handlers
4. Set up OAuth flows for each provider (GitHub, Notion, Trello)
5. Test webhook endpoints
6. Verify service runs on port 5006

**Key Files:**
- `platform-services/backend/deepiri-external-bridge-service/server.js` - Service server
- `platform-services/backend/deepiri-external-bridge-service/src/webhookService.js` - Webhook processing
- `platform-services/backend/deepiri-external-bridge-service/src/index.js` - Route handlers
- `platform-services/backend/deepiri-external-bridge-service/Dockerfile` - Container definition

**OAuth Setup:**
```bash
# Get OAuth credentials from:
# - GitHub: https://github.com/settings/developers
# - Notion: https://www.notion.so/my-integrations
# - Trello: https://trello.com/app-key
# - Google: https://console.cloud.google.com/apis/credentials
```

**Webhook Testing:**
```bash
# Test webhook locally using ngrok
ngrok http 5000

# Configure webhook URLs in provider settings
# GitHub: Settings > Webhooks > Add webhook
# Notion: Integration settings > Webhooks
# Trello: Power-Ups > Webhooks
```

---

### Backend Engineer 1 (Avatar) - External Integrations (Updated)

**Additional Setup:**
```bash
cd platform-services/backend/deepiri-external-bridge-service

# Install OAuth libraries
npm install passport passport-oauth2
npm install axios
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-external-bridge-service/README.md`
2. Set up OAuth flows for Notion, Trello, GitHub
3. Implement webhook handlers
4. Create data synchronization logic

**Key Files:**
- `platform-services/backend/deepiri-external-bridge-service/` (create service structure)
- `deepiri-core-api/services/integrationService.js` (existing)

**Service Structure:**
```
platform-services/backend/deepiri-external-bridge-service/
├── src/
│   ├── notion.js
│   ├── trello.js
│   ├── github.js
│   ├── oauth.js
│   └── webhooks.js
├── package.json
└── server.js
```

**Testing:**
```bash
# Test OAuth flow
curl -X POST http://localhost:5000/api/integrations/notion/connect
```

---

### Backend Engineer 2 - Real-time Systems

**Additional Setup:**
```bash
# Install WebSocket and real-time libraries
npm install socket.io
npm install ws
npm install redis  # For pub/sub
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-realtime-gateway/server.js` - WebSocket service server
2. Review `platform-services/backend/deepiri-notification-service/server.js` - Notification service with WebSocket
3. Review `platform-services/backend/deepiri-realtime-gateway/README.md`
4. Test WebSocket connections on port 5008
5. Implement challenge update broadcasting
6. Create multiplayer session management
7. Set up presence tracking

**Key Files:**
- `platform-services/backend/deepiri-realtime-gateway/server.js` - WebSocket service (port 5008)
- `platform-services/backend/deepiri-notification-service/server.js` - Notification service (port 5005)
- `platform-services/backend/deepiri-notification-service/src/websocketService.js` - WebSocket handler
- `docker-compose.dev.yml` - Service configuration

**WebSocket Setup:**
```javascript
// Example: Initialize WebSocket service
const { WebSocketService } = require('./platform-services/backend/deepiri-notification-service/src/websocketService');
const wsService = new WebSocketService();
wsService.initialize(server);
```

---

### Backend Engineer 2 - Real-time Systems (Updated)

**Additional Setup:**
```bash
# Install WebSocket libraries
npm install socket.io
npm install redis
npm install ioredis
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-realtime-gateway/README.md`
2. Set up Socket.IO server
3. Implement challenge update broadcasting
4. Create multiplayer session management
5. Set up presence tracking

**Key Files:**
- `platform-services/backend/deepiri-realtime-gateway/` (create service)
- `deepiri-core-api/services/` (review existing)

**Service Structure:**
```
platform-services/backend/deepiri-realtime-gateway/
├── src/
│   ├── server.js
│   ├── challenge_updates.js
│   ├── multiplayer.js
│   └── presence.js
├── package.json
└── server.js
```

**Testing:**
```bash
# Test WebSocket connection
# Use Socket.IO client or Postman
```

---

### Backend Engineer 3 (Alex Truong) - AI Integration

**Additional Setup:**
```bash
# Install HTTP client for Python service
npm install axios
npm install node-fetch

# Python setup (if needed)
cd diri-cyrex
pip install -r requirements.txt
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-challenge-service/server.js` - Challenge service (port 5007)
2. Review `diri-cyrex/app/routes/challenge.py` - Python AI routes
3. Review `diri-cyrex/app/services/` - All AI services
4. Test challenge service → Python AI service communication
5. Implement challenge state management
6. Set up AI response validation

**Key Files:**
- `platform-services/backend/deepiri-challenge-service/server.js` - Challenge service (port 5007)
- `platform-services/backend/deepiri-challenge-service/src/index.js` - Route handlers
- `diri-cyrex/app/routes/challenge.py` - Python AI routes
- `diri-cyrex/app/services/challenge_generator.py` - Challenge generation
- `diri-cyrex/app/services/rl_environment.py` - RL environment
- `diri-cyrex/app/services/ppo_agent.py` - PPO agent

**Integration Example:**
```javascript
// Call Python AI service with new endpoints
const response = await axios.post('http://localhost:8000/api/challenge/generate', {
  task: taskData,
  user_profile: userProfile
});

// Call RL environment
const rlResponse = await axios.post('http://localhost:8000/api/rl/optimize', {
  challenge_data: challengeData
});
```

---

### Backend Engineer 3 (Alex Truong) - AI Integration (Updated)

**Additional Setup:**
```bash
# Install HTTP client for Python service
npm install axios
npm install node-fetch

# Python setup (if needed)
cd diri-cyrex
pip install -r requirements.txt
```

**First Tasks:**
1. Review `diri-cyrex/app/routes/challenge.py`
2. Review `diri-cyrex/app/services/`
3. Create challenge state management
4. Implement gamification rule engine
5. Set up AI response validation

**Key Files:**
- `diri-cyrex/app/routes/challenge.py`
- `diri-cyrex/app/services/challenge_generator.py`
- `platform-services/backend/deepiri-challenge-service/` (create)

**Integration Example:**
```javascript
// Call Python AI service
const response = await axios.post('http://localhost:8000/api/challenge/generate', {
  task: taskData
});
```

---

### Backend Engineer 4 - Data & Performance

**Additional Setup:**
```bash
# Install database and caching tools
npm install mongoose
npm install redis
npm install mongodb
npm install @influxdata/influxdb-client  # For time-series analytics
```

**First Tasks:**
1. Review database models
2. Review `platform-services/backend/deepiri-auth-service/src/timeSeriesService.js` - NEW: Time-series service
3. Review `platform-services/backend/deepiri-platform-analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics
4. Analyze query performance
5. Set up caching strategies
6. Create database migrations
7. Implement backup systems
8. Set up InfluxDB for time-series data

**Key Files:**
- `deepiri-core-api/models/` - Database models
- `diri-cyrex/app/database/models.py` - Python models
- `diri-cyrex/app/utils/cache.py` - Caching utilities
- `platform-services/backend/deepiri-auth-service/src/timeSeriesService.js` - NEW: Time-series tracking
- `platform-services/backend/deepiri-platform-analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics

**Time-Series Setup:**
```bash
# Start InfluxDB
docker run -d --name influxdb -p 8086:8086 influxdb:2.7

# Create bucket
influx bucket create -n analytics -o deepiri
```

---

### Backend Engineer 4 - Data & Performance (Updated)

**Additional Setup:**
```bash
# Install database tools
npm install mongoose
npm install redis
npm install mongodb
```

**First Tasks:**
1. Review database models
2. Analyze query performance
3. Set up caching strategies
4. Create database migrations
5. Implement backup systems

**Key Files:**
- `deepiri-core-api/models/`
- `diri-cyrex/app/database/models.py`
- `diri-cyrex/app/utils/cache.py`

**Performance Testing:**
```bash
# Install load testing tools
npm install -g artillery

# Run load test
artillery quick --count 100 --num 10 http://localhost:5000/api/tasks
```

---

### FullStack Engineer 1 (AI) (Kenny Ng)

**Additional Setup:**
```bash
# deepiri-web-frontend setup
cd deepiri-web-frontend
npm install

# Install AI visualization libraries
npm install recharts d3
npm install react-query
```

**First Tasks:**
1. Review `deepiri-web-frontend/src/pages/ProductivityChat.jsx`
2. Create challenge generation UI
3. Implement real-time AI response handling
4. Create model output visualization
5. Integrate with AI service APIs

**Key Files:**
- `deepiri-web-frontend/src/pages/ProductivityChat.jsx`
- `deepiri-web-frontend/src/components/` (create AI components)
- `deepiri-web-frontend/src/services/challengeApi.js` (create)

**deepiri-web-frontend + Backend:**
```bash
# Start both
cd deepiri-core-api && npm run dev &
cd deepiri-web-frontend && npm run dev
```

---

### FullStack Engineer 2 (Tyler Roelfs) - Gamification

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install animation libraries
npm install framer-motion
npm install react-spring
npm install socket.io-client
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-engagement-service/src/multiCurrencyService.js` - NEW: Multi-currency
2. Review `platform-services/backend/deepiri-engagement-service/src/eloLeaderboardService.js` - NEW: ELO ranking
3. Review `platform-services/backend/deepiri-engagement-service/src/badgeSystemService.js` - NEW: Badge system
4. Review gamification service
5. Create progress tracking components
6. Implement badge animations
7. Create leaderboard with real-time updates (ELO-based)
8. Build social features interface
9. Implement multi-currency UI

**Key Files:**
- `platform-services/backend/deepiri-engagement-service/src/multiCurrencyService.js` - NEW: Multi-currency
- `platform-services/backend/deepiri-engagement-service/src/eloLeaderboardService.js` - NEW: ELO leaderboard
- `platform-services/backend/deepiri-engagement-service/src/badgeSystemService.js` - NEW: Badge system
- `platform-services/backend/deepiri-engagement-service/` - Gamification service
- `deepiri-web-frontend/src/components/gamification/` - deepiri-web-frontend components
- `deepiri-core-api/services/gamificationService.js` - Existing service

---

### FullStack Engineer 3 (Andhausen) - Integration Dashboard

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install OAuth UI libraries
npm install react-oauth
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-external-bridge-service/src/webhookService.js` - NEW: Webhook service
2. Create integration dashboard UI
3. Implement OAuth flows in deepiri-web-frontend
4. Create webhook management UI
5. Create data sync monitoring
6. Build configuration interfaces
7. Test webhook endpoints

**Key Files:**
- `platform-services/backend/deepiri-external-bridge-service/src/webhookService.js` - NEW: Webhook processing
- `deepiri-web-frontend/src/pages/integrations/` - Integration pages
- `deepiri-web-frontend/src/components/integrations/` - Integration components
- `platform-services/backend/deepiri-external-bridge-service/` - Integration service

---

### FullStack Engineer 4 - Analytics & Insights

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install charting libraries
npm install chart.js react-chartjs-2
npm install d3
npm install date-fns
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-platform-analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series
2. Review `platform-services/backend/deepiri-platform-analytics-service/src/behavioralClustering.js` - NEW: Clustering
3. Review `platform-services/backend/deepiri-platform-analytics-service/src/predictiveModeling.js` - NEW: Predictive models
4. Create analytics dashboard
5. Implement productivity visualization
6. Create real-time analytics API
7. Build data export features
8. Create insight recommendation UI
9. Integrate time-series charts
10. Implement clustering visualizations

**Key Files:**
- `platform-services/backend/deepiri-platform-analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics
- `platform-services/backend/deepiri-platform-analytics-service/src/behavioralClustering.js` - NEW: Behavioral clustering
- `platform-services/backend/deepiri-platform-analytics-service/src/predictiveModeling.js` - NEW: Predictive modeling
- `deepiri-web-frontend/src/pages/analytics/` - Analytics pages
- `platform-services/backend/deepiri-platform-analytics-service/` - Analytics service
- `deepiri-core-api/services/analyticsService.js` - Existing service

---

### Systems Architect 1 (Ethan Eatoneer)

**Additional Setup:**
```bash
# Install architecture tools
npm install -g @apollo/gateway
```

**First Tasks:**
1. Review `MICROSERVICES_ARCHITECTURE.md`
2. Design service communication patterns
3. Plan scalability architecture
4. Design service discovery
5. Plan load balancing strategy

**Key Files:**
- `MICROSERVICES_ARCHITECTURE.md`
- `platform-services/backend/deepiri-api-gateway/` (create)
- `architecture/` (create directory)

---

### Systems Architect 2 - Event-Driven Architecture

**Additional Setup:**
```bash
# Install message queue clients
npm install kafkajs
npm install amqplib  # RabbitMQ
```

**First Tasks:**
1. Design event-driven system
2. Set up message queue infrastructure
3. Design event sourcing patterns
4. Create event bus service

**Key Files:**
- `services/event-bus/` (create)
- `architecture/event_driven_design.md` (create)

---

### Systems Architect 3 - Security & Compliance

**Additional Setup:**
```bash
# Install security libraries
npm install bcrypt jsonwebtoken
npm install helmet
npm install express-rate-limit
```

**First Tasks:**
1. Review security middleware
2. Design authentication architecture
3. Plan encryption strategy
4. Design API security

**Key Files:**
- `deepiri-core-api/middleware/authenticateJWT.js`
- `architecture/security_design.md` (create)

---

### Systems Architect 4 - Scalability & Multiplayer

**Additional Setup:**
```bash
# Install scaling tools
npm install socket.io-redis
npm install cluster
```

**First Tasks:**
1. Design multiplayer scaling
2. Plan game state management
3. Design global deployment
4. Plan load balancing

**Key Files:**
- `platform-services/backend/deepiri-realtime-gateway/`
- `architecture/multiplayer_scaling.md` (create)

---

### Systems Architect Intern (Donovan Kelley)

**Setup:**
Follow basic setup, then focus on:
- Architecture documentation
- Pattern research
- Service design reviews

---

### Systems Engineer 1 (Evram Attya)

**Additional Setup:**
```bash
# Install testing tools
npm install -g newman  # Postman CLI
pip install pytest requests
```

**First Tasks:**
1. Create end-to-end tests
2. Set up system health monitoring
3. Test AI-backend integration
4. Validate cross-service communication

**Key Files:**
- `tests/integration/` (create)
- `scripts/system_health_check.sh` (create)

---

### Systems Engineer 2

**Additional Setup:**
Same as Systems Engineer 1

**First Tasks:**
1. Create integration tests
2. Test error handling
3. Test service recovery
4. Validate system behavior

---

### Platform Engineer 1 (Lead) (Nahian R)

**Additional Setup:**
```bash
# Install platform tools
npm install -g vercel
npm install -g netlify-cli
```

**First Tasks:**
1. Set up internal developer platform
2. Create CI/CD pipelines
3. Set up developer tooling
4. Improve developer experience

**Key Files:**
- `.github/workflows/` (create)
- `platform/` (create directory)

---

### Platform Engineer 2

**Additional Setup:**
```bash
# Install IaC tools
# Install Terraform
# Install Ansible (optional)
```

**First Tasks:**
1. Create Terraform configs
2. Set up Kubernetes configs
3. Create Docker configs
4. Automate resource provisioning

**Key Files:**
- `infrastructure/terraform/` (create)
- `infrastructure/kubernetes/` (create)

---

### Cloud/Infrastructure Engineers

**Additional Setup:**
```bash
# Install cloud CLIs
# AWS CLI, GCP CLI, Azure CLI
pip install awscli
```

**First Tasks:**
1. Set up cloud resources
2. Configure networking
3. Set up monitoring
4. Plan disaster recovery

---

### DevOps Engineer

**Additional Setup:**
```bash
# Install monitoring tools
npm install -g pm2
```

**First Tasks:**
1. Set up CI/CD pipelines
2. Configure monitoring
3. Set up observability
4. Automate deployments

---

### Backend Interns

**Setup:**
Follow basic setup, then focus on your area:
- **Intern 1:** Testing and CI/CD
- **Intern 2:** Documentation and logging
- **Intern 3:** Performance testing

## Development Workflow

### 1. Service Development

```bash
# Create new service
cd services
mkdir new-service
cd new-service
npm init -y

# Install dependencies
npm install fastify
npm install mongoose  # if using MongoDB
```

### 2. Testing

```bash
# Run tests
npm test

# Run integration tests
npm run test:integration
```

### 3. API Documentation

```bash
# Use Swagger/OpenAPI
npm install @fastify/swagger
```

### 4. Docker Development

```bash
# Build service
docker build -t service-name .

# Run with docker-compose
docker-compose up service-name
```

## Key Resources

### Documentation

- **Backend Team README:** `README_BACKEND_TEAM.md`
- **Microservices Architecture:** `MICROSERVICES_ARCHITECTURE.md`
- **FIND_YOUR_TASKS:** `FIND_YOUR_TASKS.md`
- **Getting Started:** `GETTING_STARTED.md`
- **Environment Variables:** `ENVIRONMENT_VARIABLES.md`

### Important Directories

- `deepiri-core-api/` - Main backend API
- `services/` - Microservices
- `diri-cyrex/` - AI service integration
- `ops/` - Deployment configs

### Communication

- Team Discord/Slack channel
- Weekly standups
- Code review process
- Architecture discussions

## Getting Help

1. Check `FIND_YOUR_TASKS.md` for your role
2. Review `README_BACKEND_TEAM.md`
3. Ask in team channels
4. Contact Backend Lead
5. Review existing service examples

---

**Welcome to the Backend Team! Let's build scalable microservices.**




