# Task Service

Manages user tasks.

## Responsibilities
- Task CRUD operations
- Task metadata management
- Task completion tracking
- Task filtering and search

## Endpoints
- `GET /tasks`
- `POST /tasks`
- `GET /tasks/:id`
- `PATCH /tasks/:id`
- `DELETE /tasks/:id`
- `POST /tasks/:id/complete`

## Current Implementation
See `api-server/services/taskService.js` and `api-server/routes/taskRoutes.js`

## Migration
Extract from `api-server/` to this independent service.

