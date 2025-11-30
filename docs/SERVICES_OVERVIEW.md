# Services Overview

Complete guide to all services running in the Deepiri development environment.

---

## 📊 Visual Services (Web UIs)

These services provide web-based user interfaces that you can access in your browser.

### 1. **Frontend Application** 🎨
- **URL:** http://localhost:5173
- **Port:** 5173
- **Service Name:** `frontend-dev`
- **Description:** Main React/Vite frontend application with hot module reloading
- **How to Access:**
  ```bash
  # Open in browser
  open http://localhost:5173
  # or
  start http://localhost:5173  # Windows
  ```
- **Testing:**
  - Navigate to http://localhost:5173
  - The app should load with the Deepiri interface
  - Check browser console for any errors
  - Hot reload is enabled - changes to code will auto-refresh

---

### 2. **Mongo Express** 🗄️
- **URL:** http://localhost:8081
- **Port:** 8081
- **Service Name:** `mongo-express`
- **Description:** Web-based MongoDB administration interface
- **How to Access:**
  ```bash
  open http://localhost:8081
  ```
- **Testing:**
  - Navigate to http://localhost:8081
  - No authentication required (dev mode)
  - Browse databases, collections, and documents
  - Run queries and view data
  - Create/edit/delete documents

---

### 3. **InfluxDB UI** 📈
- **URL:** http://localhost:8086
- **Port:** 8086
- **Service Name:** `influxdb`
- **Description:** InfluxDB web interface for time-series data management
- **How to Access:**
  ```bash
  open http://localhost:8086
  ```
- **Testing:**
  - Navigate to http://localhost:8086
  - Default credentials (if not set in env):
    - Username: `admin`
    - Password: `adminpassword`
    - Organization: `deepiri`
    - Bucket: `analytics`
  - View dashboards, run queries, manage data sources

---

### 4. **MLflow UI** 🤖
- **URL:** http://localhost:5500
- **Port:** 5500 (mapped from container port 5000)
- **Service Name:** `mlflow`
- **Description:** MLflow tracking server UI for AI experiment management
- **How to Access:**
  ```bash
  open http://localhost:5500
  ```
- **Testing:**
  - Navigate to http://localhost:5500
  - View ML experiments, runs, and metrics
  - Compare model performance
  - Download artifacts and models
  - No authentication required (dev mode)

---

### 5. **Jupyter Notebook** 📓
- **URL:** http://localhost:8888
- **Port:** 8888
- **Service Name:** `jupyter`
- **Description:** Jupyter Notebook server for AI research and experimentation
- **How to Access:**
  ```bash
  open http://localhost:8888
  ```
- **Testing:**
  - Navigate to http://localhost:8888
  - No token/password required (dev mode)
  - Create and run Python notebooks
  - Access notebooks in `/app/notebooks` directory
  - Data available in `/app/data` directory

---

## 🔌 API Services

These services provide REST APIs and can be tested via HTTP requests.

### 6. **API Gateway** 🚪
- **URL:** http://localhost:5000
- **Port:** 5000
- **Service Name:** `api-gateway`
- **Description:** Central API gateway that routes requests to all microservices
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5000/health
  
  # Example: Access auth service through gateway
  curl http://localhost:5000/api/auth/health
  
  # Example: Access cyrex service through gateway
  curl http://localhost:5000/api/cyrex/health
  ```
- **Endpoints:**
  - Routes to all services under `/api/{service-name}`
  - Health: `GET /health`
  - All service endpoints are proxied through this gateway

---

### 7. **Auth Service** 🔐
- **URL:** http://localhost:5001
- **Port:** 5001
- **Service Name:** `auth-service`
- **Description:** Authentication and authorization service (OAuth, social login, skill trees)
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5001/health
  
  # Check service status
  curl http://localhost:5001/api/status
  
  # Example: User registration (if endpoint exists)
  curl -X POST http://localhost:5001/api/users/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"test123"}'
  ```
- **Key Features:**
  - OAuth integration
  - Social graph management
  - Skill tree system
  - Time-series analytics for user behavior

---

### 8. **Task Orchestrator** 📋
- **URL:** http://localhost:5002
- **Port:** 5002
- **Service Name:** `task-orchestrator`
- **Description:** Manages task dependencies, versioning, and orchestration
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5002/health
  
  # Get tasks
  curl http://localhost:5002/api/tasks
  
  # Create a task
  curl -X POST http://localhost:5002/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Task","description":"Testing"}'
  ```
- **Key Features:**
  - Task dependency graph
  - Task versioning
  - Workflow orchestration

---

### 9. **Engagement Service** 🎯
- **URL:** http://localhost:5003
- **Port:** 5003
- **Service Name:** `engagement-service`
- **Description:** Multi-currency system, ELO leaderboards, and badge management
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5003/health
  
  # Get leaderboard
  curl http://localhost:5003/api/leaderboard
  
  # Get user badges
  curl http://localhost:5003/api/users/{userId}/badges
  
  # Get user currency balance
  curl http://localhost:5003/api/users/{userId}/currency
  ```
- **Key Features:**
  - Multi-currency system
  - ELO rating system
  - Badge/achievement system
  - Leaderboards

---

### 10. **Platform Analytics Service** 📊
- **URL:** http://localhost:5004
- **Port:** 5004
- **Service Name:** `platform-analytics-service`
- **Description:** Analytics, predictive modeling, and behavioral clustering
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5004/health
  
  # Get analytics dashboard data
  curl http://localhost:5004/api/analytics/dashboard
  
  # Get predictive insights
  curl http://localhost:5004/api/analytics/predictions
  
  # Get behavioral clusters
  curl http://localhost:5004/api/analytics/clusters
  ```
- **Key Features:**
  - Time-series analytics
  - Predictive modeling
  - Behavioral clustering
  - User segmentation

---

### 11. **Notification Service** 🔔
- **URL:** http://localhost:5005
- **Port:** 5005
- **Service Name:** `notification-service`
- **Description:** Push notifications, email, SMS, and WebSocket notifications
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5005/health
  
  # Send notification
  curl -X POST http://localhost:5005/api/notifications \
    -H "Content-Type: application/json" \
    -d '{"userId":"user123","type":"push","title":"Test","message":"Hello"}'
  
  # Get user notifications
  curl http://localhost:5005/api/notifications/user/{userId}
  ```
- **Key Features:**
  - Push notifications (FCM, APNS)
  - Email notifications
  - SMS notifications
  - WebSocket real-time notifications

---

### 12. **External Bridge Service** 🌉
- **URL:** http://localhost:5006
- **Port:** 5006
- **Service Name:** `external-bridge-service`
- **Description:** Integrations with GitHub, Notion, Trello, and webhook management
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5006/health
  
  # List integrations
  curl http://localhost:5006/api/integrations
  
  # Connect GitHub
  curl -X POST http://localhost:5006/api/integrations/github/connect \
    -H "Content-Type: application/json" \
    -d '{"code":"github_oauth_code"}'
  
  # Get webhooks
  curl http://localhost:5006/api/webhooks
  ```
- **Key Features:**
  - GitHub integration
  - Notion integration
  - Trello integration
  - Webhook management

---

### 13. **Challenge Service** 🏆
- **URL:** http://localhost:5007
- **Port:** 5007
- **Service Name:** `challenge-service`
- **Description:** AI-powered challenges, competitions, and gamification
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5007/health
  
  # Get active challenges
  curl http://localhost:5007/api/challenges
  
  # Create a challenge
  curl -X POST http://localhost:5007/api/challenges \
    -H "Content-Type: application/json" \
    -d '{"title":"AI Challenge","description":"Test challenge"}'
  
  # Submit challenge solution
  curl -X POST http://localhost:5007/api/challenges/{challengeId}/submit \
    -H "Content-Type: application/json" \
    -d '{"solution":"my solution"}'
  ```
- **Key Features:**
  - AI-powered challenge generation
  - Competition management
  - Solution evaluation via Cyrex AI service

---

### 14. **Realtime Gateway** ⚡
- **URL:** http://localhost:5008
- **Port:** 5008
- **Service Name:** `realtime-gateway`
- **Description:** WebSocket gateway for real-time communication
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:5008/health
  
  # WebSocket connection (use a WebSocket client)
  # Example with wscat:
  npm install -g wscat
  wscat -c ws://localhost:5008
  
  # Or use browser WebSocket API:
  const ws = new WebSocket('ws://localhost:5008');
  ws.onopen = () => console.log('Connected');
  ws.onmessage = (msg) => console.log('Received:', msg.data);
  ```
- **Key Features:**
  - WebSocket connections
  - Real-time updates
  - Event broadcasting
  - Live collaboration

---

### 15. **Cyrex AI Service** 🤖
- **URL:** http://localhost:8000
- **Port:** 8000
- **Service Name:** `cyrex`
- **Description:** AI/ML service for natural language processing, embeddings, and model inference
- **How to Test:**
  ```bash
  # Health check
  curl http://localhost:8000/health
  
  # Get service info
  curl http://localhost:8000/api/info
  
  # Example: Text embedding
  curl -X POST http://localhost:8000/api/embeddings \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello world"}'
  
  # Example: AI completion
  curl -X POST http://localhost:8000/api/complete \
    -H "Content-Type: application/json" \
    -d '{"prompt":"What is AI?","max_tokens":100}'
  ```
- **Key Features:**
  - OpenAI integration
  - Sentence transformers
  - Vector embeddings
  - Model inference
  - RAG (Retrieval Augmented Generation)

---

## 🗄️ Infrastructure Services

These are database and cache services that support the application.

### 16. **MongoDB** 🍃
- **Port:** 27017
- **Service Name:** `mongodb`
- **Description:** Primary NoSQL database for application data
- **How to Test:**
  ```bash
  # Connect via MongoDB client
  mongosh mongodb://admin:password@localhost:27017/deepiri?authSource=admin
  
  # Or use mongo-express UI at http://localhost:8081
  
  # Test connection
  docker exec -it deepiri-mongodb-dev mongosh \
    -u admin -p password \
    --authenticationDatabase admin
  ```
- **Default Credentials:**
  - Username: `admin` (or from `MONGO_ROOT_USER` env var)
  - Password: `password` (or from `MONGO_ROOT_PASSWORD` env var)
  - Database: `deepiri` (or from `MONGO_DB` env var)

---

### 17. **Redis** 🔴
- **Port:** 6380 (host) → 6379 (container)
- **Service Name:** `redis`
- **Description:** In-memory cache and session store
- **How to Test:**
  ```bash
  # Connect via redis-cli
  redis-cli -h localhost -p 6380 -a redispassword
  
  # Test commands
  redis-cli -h localhost -p 6380 -a redispassword SET test "hello"
  redis-cli -h localhost -p 6380 -a redispassword GET test
  
  # Or via Docker
  docker exec -it deepiri-redis-dev redis-cli -a redispassword
  ```
- **Default Password:** `redispassword` (or from `REDIS_PASSWORD` env var)

---

## Quick Reference

### All Service URLs

| Service | Type | URL | Port |
|---------|------|-----|------|
| Frontend | Visual | http://localhost:5173 | 5173 |
| Mongo Express | Visual | http://localhost:8081 | 8081 |
| InfluxDB UI | Visual | http://localhost:8086 | 8086 |
| MLflow UI | Visual | http://localhost:5500 | 5500 |
| Jupyter | Visual | http://localhost:8888 | 8888 |
| API Gateway | API | http://localhost:5000 | 5000 |
| Auth Service | API | http://localhost:5001 | 5001 |
| Task Orchestrator | API | http://localhost:5002 | 5002 |
| Engagement Service | API | http://localhost:5003 | 5003 |
| Platform Analytics | API | http://localhost:5004 | 5004 |
| Notification Service | API | http://localhost:5005 | 5005 |
| External Bridge | API | http://localhost:5006 | 5006 |
| Challenge Service | API | http://localhost:5007 | 5007 |
| Realtime Gateway | API | http://localhost:5008 | 5008 |
| Cyrex AI | API | http://localhost:8000 | 8000 |
| MongoDB | Database | mongodb://localhost:27017 | 27017 |
| Redis | Data Transmission / Cache | redis://localhost:6380 | 6380 |

---

## 🧪 Testing Tools

### Health Check All Services
```bash
# Check all services at once
for port in 5000 5001 5002 5003 5004 5005 5006 5007 5008 8000; do
  echo "Testing port $port..."
  curl -s http://localhost:$port/health || echo "Failed"
done
```

### View Service Logs
```bash
# View logs for a specific service
docker compose -f docker-compose.dev.yml logs -f <service-name>

# Examples:
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f frontend-dev
```

### Check Service Status
```bash
# List all running services
docker compose -f docker-compose.dev.yml ps

# Check specific service
docker compose -f docker-compose.dev.yml ps <service-name>
```

---

## 🔍 Service Discovery

### Find Service by Port
```bash
# Find which service uses a port
docker compose -f docker-compose.dev.yml ps | grep <port>
```

### List All Service Names
```bash
# Get all service names from docker-compose
docker compose -f docker-compose.dev.yml config --services
```

---

## 📚 Additional Resources

- **API Documentation:** Check each service's `/docs` or `/api-docs` endpoint (if available)
- **Service Logs:** Use `docker compose logs` to debug issues
- **Database Access:** Use Mongo Express (http://localhost:8081) for MongoDB
- **Monitoring:** Check service health endpoints regularly

---

## 🚨 Troubleshooting

### Service Not Responding?
1. Check if service is running: `docker compose ps <service-name>`
2. Check logs: `docker compose logs <service-name>`
3. Check health endpoint: `curl http://localhost:<port>/health`
4. Restart service: `docker compose restart <service-name>`

### Port Already in Use?
- Check what's using the port: `netstat -ano | findstr :<port>` (Windows) or `lsof -i :<port>` (Linux/Mac)
- Change port in `docker-compose.dev.yml` if needed

### Service Dependencies?
- Services depend on databases (MongoDB, Redis, InfluxDB)
- Check that infrastructure services are running first
- Use `depends_on` in docker-compose to ensure startup order

---

**Last Updated:** 2025-11-22

