# Microservices Architecture - Deepiri

## Current Structure
All services are currently in `deepiri-core-api/` as a monolith. This document outlines the target microservices architecture.

## Target Microservices

### 1. API Gateway
**Location**: `platform-services/backend/deepiri-api-gateway/`
- Routes requests to appropriate services
- Authentication/authorization
- Rate limiting
- Request/response transformation

### 2. User Service
**Location**: `platform-services/backend/deepiri-auth-service/`
- User registration and authentication
- Profile management
- User preferences
- Firebase integration

### 3. Task Service
**Location**: `platform-services/backend/deepiri-task-orchestrator/`
- Task CRUD operations
- Task metadata management
- Task completion tracking
- Task filtering and search

### 4. Challenge Service
**Location**: `platform-services/backend/deepiri-challenge-service/`
- Challenge generation (calls AI service)
- Challenge completion tracking
- Challenge state management
- Challenge linking to tasks

### 5. Gamification Service
**Location**: `platform-services/backend/deepiri-engagement-service/`
- Points and XP system
- Badge management
- Leaderboard functionality
- Streak tracking
- Level progression

### 6. Analytics Service
**Location**: `platform-services/backend/deepiri-platform-analytics-service/`
- Performance tracking
- Efficiency calculations
- Productivity insights
- Time management analytics

### 7. Integration Service
**Location**: `platform-services/backend/deepiri-external-bridge-service/`
- External API integrations (Notion, Trello, GitHub)
- OAuth flows
- Webhook management
- Data synchronization

### 8. Notification Service
**Location**: `platform-services/backend/deepiri-notification-service/`
- Real-time notifications
- Notification preferences
- Notification history

### 9. WebSocket Service
**Location**: `platform-services/backend/deepiri-realtime-gateway/`
- WebSocket server
- Real-time challenge updates
- Multiplayer sessions
- Presence tracking

## Service Communication

### Inter-Service Communication
- REST API for synchronous communication
- Message queue (Redis/RabbitMQ) for async communication
- gRPC for high-performance services (optional)

### Service Discovery
- Service registry
- Health checks
- Load balancing

## Database Per Service
Each service should have its own database or database schema:
- User Service → `users` collection
- Task Service → `tasks` collection
- Challenge Service → `challenges` collection
- Gamification Service → `gamification` collection
- Analytics Service → `analytics` collection
- Integration Service → `integrations` collection
- Notification Service → `notifications` collection

## Migration Strategy
1. Keep current monolith working
2. Extract services one by one
3. Update API Gateway to route to new services
4. Test each service independently
5. Deploy services separately

## Current Implementation
The current `deepiri-core-api/` structure serves as the foundation. Services are logically separated in:
- `services/` - Business logic
- `routes/` - API endpoints
- `models/` - Database schemas

This structure can be gradually split into independent microservices.




