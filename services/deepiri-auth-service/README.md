# User Service

Handles user management and authentication.

## Responsibilities
- User registration
- User authentication (JWT)
- Profile management
- User preferences
- Firebase integration

## Endpoints
- `POST /users/register`
- `POST /users/login`
- `GET /users/profile`
- `PATCH /users/profile`

## Current Implementation
See `api-server/services/userService.js` and `api-server/routes/userRoutes.js`

## Migration
Extract from `api-server/` to this independent service.

