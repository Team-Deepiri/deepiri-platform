# Notification Service

Handles user notifications.

## Responsibilities
- Real-time notifications
- Notification preferences
- Notification history

## Endpoints
- `GET /notifications`
- `POST /notifications/mark-read`
- `GET /notifications/preferences`
- `PATCH /notifications/preferences`

## Current Implementation
See `api-server/services/notificationService.js` and `api-server/routes/notificationRoutes.js`

## Migration
Extract from `api-server/` to this independent service.

