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

