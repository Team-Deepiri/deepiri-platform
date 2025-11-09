# Backend Team Onboarding Guide

Welcome to the Deepiri Backend Team! This guide will help you get set up and start building microservices.

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
cd Deepiri/deepiri
```

### 2. Environment Configuration

```bash
# Copy environment templates
cp env.example .env
cp env.example.server api-server/.env

# Edit .env files with your configuration
```

### 3. Database Setup

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

### 4. Backend API Setup

```bash
cd api-server

# Install dependencies
npm install

# Start development server
npm run dev
```

Backend runs on http://localhost:5000

### 5. Python AI Service Setup (for AI Integration)

```bash
cd python_backend

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
1. Review `MICROSERVICES_ARCHITECTURE.md`
2. Review all services in `services/`
3. Review `api-server/` structure
4. Coordinate with AI Systems Lead
5. Plan service extraction strategy

**Key Files:**
- `MICROSERVICES_ARCHITECTURE.md`
- `services/README.md`
- `api-server/server.js`

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
1. Review `services/integration-service/src/webhookService.js` - NEW: Webhook service
2. Review OAuth flows for each provider
3. Set up webhook endpoints
4. Implement OAuth 2.0 flows
5. Test integration connections

**Key Files:**
- `services/integration-service/src/webhookService.js` - NEW: Webhook processing
- `services/integration-service/src/` - Integration service
- `api-server/services/integrationService.js` - Existing integration service

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
cd services/integration-service

# Install OAuth libraries
npm install passport passport-oauth2
npm install axios
```

**First Tasks:**
1. Review `services/integration-service/README.md`
2. Set up OAuth flows for Notion, Trello, GitHub
3. Implement webhook handlers
4. Create data synchronization logic

**Key Files:**
- `services/integration-service/` (create service structure)
- `api-server/services/integrationService.js` (existing)

**Service Structure:**
```
services/integration-service/
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
1. Review `services/notification-service/src/websocketService.js` - NEW: WebSocket service
2. Review `services/websocket-service/README.md`
3. Set up Socket.IO server
4. Implement challenge update broadcasting
5. Create multiplayer session management
6. Set up presence tracking
7. Integrate with notification service

**Key Files:**
- `services/notification-service/src/websocketService.js` - NEW: WebSocket service
- `services/websocket-service/` - WebSocket service
- `api-server/services/notificationService.js` - Notification service

**WebSocket Setup:**
```javascript
// Example: Initialize WebSocket service
const { WebSocketService } = require('./services/notification-service/src/websocketService');
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
1. Review `services/websocket-service/README.md`
2. Set up Socket.IO server
3. Implement challenge update broadcasting
4. Create multiplayer session management
5. Set up presence tracking

**Key Files:**
- `services/websocket-service/` (create service)
- `api-server/services/` (review existing)

**Service Structure:**
```
services/websocket-service/
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
cd python_backend
pip install -r requirements.txt
```

**First Tasks:**
1. Review `python_backend/app/routes/challenge.py`
2. Review `python_backend/app/services/` - NEW: All new AI services
3. Review `python_backend/app/services/rl_environment.py` - NEW: RL environment
4. Review `python_backend/app/services/ppo_agent.py` - NEW: PPO agent
5. Review `python_backend/app/services/multi_agent_system.py` - NEW: Multi-agent
6. Create challenge state management
7. Implement gamification rule engine
8. Set up AI response validation

**Key Files:**
- `python_backend/app/routes/challenge.py` - Challenge routes
- `python_backend/app/services/challenge_generator.py` - Challenge generation
- `python_backend/app/services/rl_environment.py` - NEW: RL environment
- `python_backend/app/services/ppo_agent.py` - NEW: PPO agent
- `python_backend/app/services/multi_agent_system.py` - NEW: Multi-agent
- `services/challenge-service/` - Challenge service

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
cd python_backend
pip install -r requirements.txt
```

**First Tasks:**
1. Review `python_backend/app/routes/challenge.py`
2. Review `python_backend/app/services/`
3. Create challenge state management
4. Implement gamification rule engine
5. Set up AI response validation

**Key Files:**
- `python_backend/app/routes/challenge.py`
- `python_backend/app/services/challenge_generator.py`
- `services/challenge-service/` (create)

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
2. Review `services/user-service/src/timeSeriesService.js` - NEW: Time-series service
3. Review `services/analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics
4. Analyze query performance
5. Set up caching strategies
6. Create database migrations
7. Implement backup systems
8. Set up InfluxDB for time-series data

**Key Files:**
- `api-server/models/` - Database models
- `python_backend/app/database/models.py` - Python models
- `python_backend/app/utils/cache.py` - Caching utilities
- `services/user-service/src/timeSeriesService.js` - NEW: Time-series tracking
- `services/analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics

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
- `api-server/models/`
- `python_backend/app/database/models.py`
- `python_backend/app/utils/cache.py`

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
# Frontend setup
cd frontend
npm install

# Install AI visualization libraries
npm install recharts d3
npm install react-query
```

**First Tasks:**
1. Review `frontend/src/pages/ProductivityChat.jsx`
2. Create challenge generation UI
3. Implement real-time AI response handling
4. Create model output visualization
5. Integrate with AI service APIs

**Key Files:**
- `frontend/src/pages/ProductivityChat.jsx`
- `frontend/src/components/` (create AI components)
- `frontend/src/services/challengeApi.js` (create)

**Frontend + Backend:**
```bash
# Start both
cd api-server && npm run dev &
cd frontend && npm run dev
```

---

### FullStack Engineer 2 (Tyler Roelfs) - Gamification

**Additional Setup:**
```bash
cd frontend

# Install animation libraries
npm install framer-motion
npm install react-spring
npm install socket.io-client
```

**First Tasks:**
1. Review `services/gamification-service/src/multiCurrencyService.js` - NEW: Multi-currency
2. Review `services/gamification-service/src/eloLeaderboardService.js` - NEW: ELO ranking
3. Review `services/gamification-service/src/badgeSystemService.js` - NEW: Badge system
4. Review gamification service
5. Create progress tracking components
6. Implement badge animations
7. Create leaderboard with real-time updates (ELO-based)
8. Build social features interface
9. Implement multi-currency UI

**Key Files:**
- `services/gamification-service/src/multiCurrencyService.js` - NEW: Multi-currency
- `services/gamification-service/src/eloLeaderboardService.js` - NEW: ELO leaderboard
- `services/gamification-service/src/badgeSystemService.js` - NEW: Badge system
- `services/gamification-service/` - Gamification service
- `frontend/src/components/gamification/` - Frontend components
- `api-server/services/gamificationService.js` - Existing service

---

### FullStack Engineer 3 (Andhausen) - Integration Dashboard

**Additional Setup:**
```bash
cd frontend

# Install OAuth UI libraries
npm install react-oauth
```

**First Tasks:**
1. Review `services/integration-service/src/webhookService.js` - NEW: Webhook service
2. Create integration dashboard UI
3. Implement OAuth flows in frontend
4. Create webhook management UI
5. Create data sync monitoring
6. Build configuration interfaces
7. Test webhook endpoints

**Key Files:**
- `services/integration-service/src/webhookService.js` - NEW: Webhook processing
- `frontend/src/pages/integrations/` - Integration pages
- `frontend/src/components/integrations/` - Integration components
- `services/integration-service/` - Integration service

---

### FullStack Engineer 4 - Analytics & Insights

**Additional Setup:**
```bash
cd frontend

# Install charting libraries
npm install chart.js react-chartjs-2
npm install d3
npm install date-fns
```

**First Tasks:**
1. Review `services/analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series
2. Review `services/analytics-service/src/behavioralClustering.js` - NEW: Clustering
3. Review `services/analytics-service/src/predictiveModeling.js` - NEW: Predictive models
4. Create analytics dashboard
5. Implement productivity visualization
6. Create real-time analytics API
7. Build data export features
8. Create insight recommendation UI
9. Integrate time-series charts
10. Implement clustering visualizations

**Key Files:**
- `services/analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics
- `services/analytics-service/src/behavioralClustering.js` - NEW: Behavioral clustering
- `services/analytics-service/src/predictiveModeling.js` - NEW: Predictive modeling
- `frontend/src/pages/analytics/` - Analytics pages
- `services/analytics-service/` - Analytics service
- `api-server/services/analyticsService.js` - Existing service

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
- `services/api-gateway/` (create)
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
- `api-server/middleware/authenticateJWT.js`
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
- `services/websocket-service/`
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
- **Environment Setup:** `ENVIRONMENT_SETUP.md`

### Important Directories

- `api-server/` - Main backend API
- `services/` - Microservices
- `python_backend/` - AI service integration
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

