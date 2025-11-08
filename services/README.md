# Microservices Directory

This directory contains the separated microservices for Deepiri.

## Service Structure

Each service should have:
- `package.json` - Service dependencies
- `server.js` - Service entry point
- `routes/` - API routes
- `services/` - Business logic
- `models/` - Database models (if needed)
- `Dockerfile` - Container definition
- `.env.example` - Environment variables template

## Current Status

Services are being extracted from `api-server/` monolith. Each service will be independently deployable.

## Service Communication

Services communicate via:
- REST API (HTTP)
- Message Queue (Redis/RabbitMQ)
- WebSocket (for real-time services)

## Deployment

Each service can be deployed independently using Docker Compose or Kubernetes.

