# Integration Service

Manages external service integrations.

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
See `api-server/services/integrationService.js` and `api-server/routes/integrationRoutes.js`

## Migration
Extract from `api-server/` to this independent service.

