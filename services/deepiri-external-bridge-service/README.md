# External Bridge Service

Manages external service integrations and third-party API connections.

## Responsibilities
- External API integrations (Notion, Trello, GitHub)
- OAuth flows
- Webhook management
- Data synchronization

## Endpoints
- `GET /integrations`
- `POST /integrations/connect`
- `POST /integrations/sync`
- `DELETE /integrations/:id`

## Current Implementation
See `deepiri-core-api/services/integrationService.js` and `deepiri-core-api/routes/integrationRoutes.js`

## Migration
Extract from `deepiri-core-api/` to this independent service.

