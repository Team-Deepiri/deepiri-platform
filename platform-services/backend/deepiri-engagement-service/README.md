# Gamification Service

Handles points, badges, leaderboards, and gamification features.

## Responsibilities
- Points and XP system
- Badge management
- Leaderboard functionality
- Streak tracking
- Level progression

## Endpoints
- `GET /gamification/points`
- `GET /gamification/badges`
- `GET /gamification/leaderboard`
- `POST /gamification/award-points`
- `POST /gamification/award-badge`

## Current Implementation
See `api-server/services/gamificationService.js` and `api-server/routes/gamificationRoutes.js`

## Migration
Extract from `api-server/` to this independent service.

