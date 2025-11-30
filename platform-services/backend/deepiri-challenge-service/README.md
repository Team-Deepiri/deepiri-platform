# Challenge Service

Manages challenge generation and completion.

## Responsibilities
- Challenge generation (calls AI service)
- Challenge completion tracking
- Challenge state management
- Challenge linking to tasks

## Endpoints
- `POST /challenges/generate`
- `GET /challenges`
- `GET /challenges/:id`
- `POST /challenges/:id/complete`

## Current Implementation
See `api-server/services/challengeService.js` and `api-server/routes/challengeRoutes.js`

## AI Integration
Communicates with Python AI service at `http://cyrex:8000`

## Migration
Extract from `api-server/` to this independent service.

