# Backend Team - Deepiri

## Team Overview
The Backend Team builds and maintains Node.js/Fastify microservices, databases, REST/gRPC communication, WebSocket layer, and system architecture.

## Core Responsibilities

### Backend Lead
- Oversee microservices architecture
- API design and database schemas
- Team coordination with AI systems
- Cross-service communication patterns

### Backend Engineers
- **External Integrations**: Notion/Trello/GitHub APIs, OAuth flows, webhook management
- **Real-time Systems**: WebSocket server, live challenge updates, multiplayer sessions
- **AI Integration**: Python service communication, challenge state management, gamification rule engine
- **Data & Performance**: Database optimization, caching strategies, query performance

### FullStack Engineers
- **AI Challenge Interfaces**: Challenge generation UI, real-time AI response handling
- **Gamification UI/UX**: Interactive progress tracking, badge animations, leaderboards
- **Integration Dashboard**: External service UI, OAuth flows, data sync monitoring
- **Analytics & Insights**: Performance dashboard UI, productivity visualization

### Systems Architects
- **Core System Architecture**: Microservices design, scalability planning
- **Data & Event Architecture**: Event-driven systems, data pipelines, message queues
- **Security & Compliance**: Security architecture, data privacy, authentication
- **Scalability & Multiplayer**: Real-time session scaling, multiplayer game state, load balancing

### Systems Engineers
- Ensure AI, backend, and cloud layers behave as one coherent system
- Integration quality and end-to-end testing
- Error handling coordination

## Current Microservices Architecture

### Service Structure
```
deepiri-core-api/
├── services/          # Business logic
│   ├── userService.js
│   ├── taskService.js
│   ├── challengeService.js
│   ├── gamificationService.js
│   ├── analyticsService.js
│   ├── integrationService.js
│   ├── notificationService.js
│   ├── aiOrchestrator.js
│   └── ...
├── routes/            # API endpoints
├── models/            # MongoDB schemas
├── middleware/        # Express middleware
└── utils/             # Utilities
```

### Current Services
1. **User Service** - Authentication, profiles, preferences
2. **Task Service** - Task CRUD, metadata, completion tracking
3. **Challenge Service** - Challenge generation, completion tracking
4. **Gamification Service** - Points, badges, leaderboards, streaks
5. **Analytics Service** - Performance tracking, insights
6. **Integration Service** - External API integrations
7. **Notification Service** - Real-time notifications
8. **AI Orchestrator** - Python AI service communication

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

## Getting Started

### Prerequisites
- Node.js 18+
- MongoDB 7.0
- Redis 7.2
- Docker and Docker Compose

### Setup
```bash
cd deepiri-core-api
npm install
cp env.example.server .env
# Configure environment variables
```

### Running Services
```bash
# Development
npm run dev

# Docker
docker-compose up backend
```

### API Base URL
- Development: `http://localhost:5000/api`
- Production: Configure via environment variables

## Microservices Restructuring Plan

### Target Architecture
Each microservice should be independently deployable with:
- Own database connection
- Own API endpoints
- Own Docker container
- Service-to-service communication via REST/gRPC

### Proposed Service Separation
1. **user-service** - User management, authentication
2. **task-service** - Task CRUD operations
3. **challenge-service** - Challenge generation and management
4. **gamification-service** - Points, badges, leaderboards
5. **analytics-service** - Analytics and insights
6. **external-bridge-service** - External API integrations
7. **notification-service** - Real-time notifications
8. **realtime-gateway** - WebSocket server for real-time updates
9. **api-gateway** - API gateway for routing

## Database Architecture

### MongoDB Collections
- `users` - User accounts and profiles
- `tasks` - User tasks
- `challenges` - Generated challenges
- `gamification` - Points, badges, achievements
- `analytics` - Performance metrics
- `integrations` - External service connections
- `notifications` - User notifications
- `events` - System events

### Redis Usage
- Session caching
- Leaderboard data
- Real-time challenge state
- Rate limiting
- WebSocket connection tracking

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register user
- `POST /api/auth/login` - Login user
- `POST /api/auth/logout` - Logout user

### Tasks
- `GET /api/tasks` - Get user tasks
- `POST /api/tasks` - Create task
- `GET /api/tasks/:id` - Get task details
- `PATCH /api/tasks/:id` - Update task
- `DELETE /api/tasks/:id` - Delete task

### Challenges
- `POST /api/challenges/generate` - Generate challenge from task
- `GET /api/challenges` - Get user challenges
- `POST /api/challenges/:id/complete` - Complete challenge

### Gamification
- `GET /api/gamification/points` - Get user points
- `GET /api/gamification/badges` - Get user badges
- `GET /api/gamification/leaderboard` - Get leaderboard

## WebSocket Events

### Client → Server
- `join-room` - Join challenge room
- `challenge-update` - Update challenge progress
- `hint-request` - Request hint

### Server → Client
- `challenge-generated` - New challenge ready
- `progress-update` - Challenge progress update
- `notification` - New notification
- `leaderboard-update` - Leaderboard change

## Integration with AI Service

### Communication Pattern
```javascript
// Example: Challenge generation
const response = await axios.post('http://cyrex:8000/generate-challenge', {
  task: taskData,
  userPreferences: userPrefs
});
```

### AI Service Endpoints Used
- `POST /generate-challenge` - Generate challenge
- `POST /understand-task` - Classify task

## External Integrations

### Supported Services
- Notion API
- Trello API
- GitHub API
- Google Docs API
- OAuth 2.0 flows

### Integration Flow
1. User authorizes external service
2. OAuth callback stores tokens
3. Periodic sync jobs fetch tasks
4. Tasks imported into Deepiri
5. Challenges generated from imported tasks

## Performance Optimization

### Caching Strategy
- Redis for frequently accessed data
- MongoDB query optimization
- Response compression
- Rate limiting

### Database Optimization
- Indexes on frequently queried fields
- Aggregation pipelines for analytics
- Connection pooling
- Query result caching

## Security

### Authentication
- JWT tokens
- Firebase authentication (optional)
- Session management

### Authorization
- Role-based access control
- Resource-level permissions
- API key validation

### Data Protection
- Input sanitization
- SQL injection prevention
- XSS protection
- Rate limiting

## Next Steps
1. Separate services into independent microservices
2. Implement API gateway
3. Set up service discovery
4. Configure inter-service communication
5. Implement circuit breakers
6. Add distributed tracing
7. Set up monitoring and logging
8. Implement health checks for all services

## Resources
- Express.js Documentation
- Socket.IO Documentation
- MongoDB Documentation
- Redis Documentation
- Fastify Documentation (for new services)



