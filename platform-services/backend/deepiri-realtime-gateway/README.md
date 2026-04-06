# Realtime Gateway

Handles real-time communication and WebSocket connections.

## Responsibilities
- WebSocket server
- Real-time challenge updates
- Multiplayer sessions
- Presence tracking

## Events
- `connection` - Client connects
- `join_user_room` - Join user-specific room
- `join_adventure_room` - Join adventure room
- `challenge-update` - Challenge progress update
- `notification` - New notification

## Current Implementation
See `deepiri-core-api/server.js` for Socket.IO setup.

## Migration
Extract WebSocket functionality to this independent service.

## Streaming Flags
- `SYNAPSE_SIDECAR_URL` sets the sidecar base URL (default: `http://synapse-sidecar:8081`).
- `STREAM_CONSUMER_GROUP` sets the sidecar consumer group (default: `realtime-gateway`).
- `STREAM_CONSUMER_NAME` sets the sidecar consumer name (default: `realtime-1`).

Realtime Gateway now consumes streams via sidecar only. Redis remains part of the design, but only behind the sidecar service.

