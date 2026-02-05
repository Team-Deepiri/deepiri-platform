# Deepiri Messaging Service

Messaging service for chat, agent communication, and group messaging in the Deepiri platform.

## Features

- **Chat Rooms**: Create and manage agent chats, group chats, and direct messages
- **Messages**: Send, receive, edit, and delete messages
- **Agent Integration**: Forward messages to Cyrex agents for AI responses
- **Read Receipts**: Track message read status
- **Message Threading**: Support for threaded conversations
- **Real-time Updates**: Event publishing for WebSocket integration

## Architecture

- **Database**: PostgreSQL with Prisma ORM
- **AI Integration**: Communicates with `diri-cyrex` for agent responses
- **Real-time**: Publishes events for Realtime Gateway WebSocket broadcasting
- **Auth**: Handled by API Gateway (reads user context from headers)

## Setup

### Prerequisites

- Node.js 18+
- PostgreSQL database
- Redis (for event streaming)
- Cyrex service running

### Installation

```bash
# Install dependencies
npm install

# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:migrate

# Start development server
npm run dev
```

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
DATABASE_URL=postgresql://user:password@localhost:5432/deepiri
CYREX_URL=http://localhost:8000
CYREX_API_KEY=your-api-key
REALTIME_GATEWAY_URL=http://localhost:5008
```

## API Endpoints

### Chat Rooms

- `POST /api/v1/chats` - Create chat room
- `GET /api/v1/chats` - List chat rooms for user
- `GET /api/v1/chats/:id` - Get chat room by ID
- `PUT /api/v1/chats/:id` - Update chat room
- `POST /api/v1/chats/:id/participants` - Add participant
- `DELETE /api/v1/chats/:id/participants/:userId` - Remove participant

### Messages

- `POST /api/v1/chats/:chatRoomId/messages` - Send message
- `GET /api/v1/chats/:chatRoomId/messages` - Get messages
- `GET /api/v1/messages/:id` - Get message by ID
- `PUT /api/v1/messages/:id` - Update message
- `DELETE /api/v1/messages/:id` - Delete message
- `POST /api/v1/messages/:id/read` - Mark as read

## Database Schema

The service uses the `messaging` schema in PostgreSQL with the following models:

- `ChatRoom` - Chat rooms (agent, group, direct)
- `ChatParticipant` - Room participants
- `Message` - Messages with threading support
- `MessageReadReceipt` - Read receipts

## Integration with Cyrex

The service forwards messages to Cyrex agents when:
- Chat room type is `AGENT`
- Chat room has an `agentInstanceId`

Messages are sent to `/api/agent/invoke` endpoint in Cyrex, and responses are saved as agent messages.

## Development

```bash
# Run in development mode
npm run dev

# Build for production
npm run build

# Run production build
npm start

# Open Prisma Studio
npm run prisma:studio
```

## Docker

```bash
# Build image
docker build -t deepiri-messaging-service .

# Run container
docker run -p 5009:5009 \
  -e DATABASE_URL=postgresql://... \
  -e CYREX_URL=http://cyrex:8000 \
  deepiri-messaging-service
```

## License

MIT

