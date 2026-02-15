# Next Steps - Messaging Service Setup

## ✅ Completed Steps

1. ✅ Service created in `platform-services/backend/deepiri-messaging-service`
2. ✅ Added to `docker-compose.dev.yml`
3. ✅ Added to all team development environment scripts
4. ✅ Added to API Gateway routes (`/api/messaging` → `http://messaging-service:5009/api/v1`)

## 📋 Remaining Steps

### Step 1: Run Database Migrations

The messaging service uses Prisma for database management. You need to create and run migrations to set up the database tables.

#### Option A: Using Docker (Recommended for Development)

```bash
# Navigate to the messaging service directory
cd platform-services/backend/deepiri-messaging-service

# Install dependencies (if not already done)
npm install

# Generate Prisma client
npm run prisma:generate

# Create and apply migration
npm run prisma:migrate

# Or if you prefer to push schema directly (for development only)
npm run prisma:db:push
```

#### Option B: Using Docker Compose (If service is running)

```bash
# If the messaging service container is already running
docker exec -it deepiri-messaging-service-dev npm run prisma:migrate

# Or generate Prisma client
docker exec -it deepiri-messaging-service-dev npm run prisma:generate
```

#### Option C: Manual Migration (Production-like)

```bash
cd platform-services/backend/deepiri-messaging-service

# Set database URL (if not in .env)
export DATABASE_URL="postgresql://deepiri:deepiripassword@localhost:5432/deepiri"

# Generate Prisma client
npx prisma generate

# Create migration
npx prisma migrate dev --name init_messaging_schema

# Or deploy migration (for production)
npx prisma migrate deploy
```

### Step 2: Test the Service

#### 2.1 Start the Service

```bash
# Using backend team script
cd team_dev_environments/backend-team
./start.sh

# Or start just the messaging service
docker compose -f ../../docker-compose.dev.yml up -d messaging-service
```

#### 2.2 Check Service Health

```bash
# Health check endpoint
curl http://localhost:5009/health

# Expected response:
# {
#   "status": "healthy",
#   "service": "messaging-service",
#   "timestamp": "2024-01-01T00:00:00.000Z"
# }
```

#### 2.3 Test via API Gateway

```bash
# Health check through API Gateway
curl http://localhost:5100/api/messaging/health

# Note: The API Gateway proxies /api/messaging/* to messaging-service:5009/api/v1/*
```

#### 2.4 Test Chat Endpoints (Requires Authentication)

```bash
# Get auth token first (from auth service)
TOKEN="your-jwt-token-here"

# List chat rooms
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:5100/api/messaging/chats

# Create a chat room
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "GROUP",
    "name": "Test Chat",
    "userIds": ["user-id-1", "user-id-2"]
  }' \
  http://localhost:5100/api/messaging/chats
```

### Step 3: Verify API Gateway Integration

The API Gateway has been updated to proxy requests to the messaging service:

- **Gateway Route**: `/api/messaging/*`
- **Target Service**: `http://messaging-service:5009`
- **Path Rewrite**: `/api/messaging` → `/api/v1`

#### Test Routes:

```bash
# Health check
curl http://localhost:5100/api/messaging/health

# Chat routes (requires auth)
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:5100/api/messaging/chats

# Message routes (requires auth)
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:5100/api/messaging/chats/{chatRoomId}/messages
```

### Step 4: Environment Variables

Make sure the following environment variables are set:

#### For Messaging Service:
```bash
PORT=5009
DATABASE_URL=postgresql://deepiri:deepiripassword@postgres:5432/deepiri
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redispassword
CYREX_URL=http://cyrex:8000
CYREX_API_KEY=change-me
REALTIME_GATEWAY_URL=http://realtime-gateway:5008
```

#### For API Gateway:
```bash
MESSAGING_SERVICE_URL=http://messaging-service:5009
```

These are already configured in `docker-compose.dev.yml`, but you can override them in:
- `ops/k8s/configmaps/messaging-service.yaml`
- `ops/k8s/configmaps/api-gateway.yaml`
- Or via `.env` file

### Step 5: Database Schema Verification

After running migrations, verify the tables were created:

```bash
# Connect to PostgreSQL
docker exec -it deepiri-postgres-dev psql -U deepiri -d deepiri

# List tables
\dt

# You should see:
# - chat_rooms
# - chat_participants
# - messages
# - message_read_receipts

# Check table structure
\d chat_rooms
\d messages
```

### Step 6: Frontend Integration

The frontend can now use the messaging API through the API Gateway:

```typescript
// Example API calls from frontend
const API_BASE = 'http://localhost:5100/api/messaging';

// Get chat rooms
const response = await fetch(`${API_BASE}/chats`, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});

// Send message
await fetch(`${API_BASE}/chats/${chatRoomId}/messages`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    content: 'Hello!',
    messageType: 'TEXT'
  })
});
```

## 🔍 Troubleshooting

### Issue: Migration fails with "relation already exists"

**Solution**: The tables might already exist. Try:
```bash
npm run prisma:db:push  # This will sync schema without creating migration
```

### Issue: Service won't start

**Check**:
1. Database is running: `docker ps | grep postgres`
2. Database URL is correct in environment
3. Prisma client is generated: `npm run prisma:generate`

### Issue: API Gateway returns 503

**Check**:
1. Messaging service is running: `docker ps | grep messaging-service`
2. Service health endpoint works: `curl http://localhost:5009/health`
3. API Gateway has correct service URL: Check `MESSAGING_SERVICE_URL` env var

### Issue: Authentication errors

**Check**:
1. Auth service is running
2. JWT token is valid
3. User context is being passed correctly (API Gateway should forward auth headers)

## 📚 Additional Resources

- **Prisma Documentation**: https://www.prisma.io/docs
- **API Gateway Routes**: See `deepiri-api-gateway/src/server.ts`
- **Messaging Service API**: See `deepiri-messaging-service/src/routes/`

## ✅ Completion Checklist

- [ ] Dependencies installed (`npm install`)
- [ ] Prisma client generated (`npm run prisma:generate`)
- [ ] Database migrations run (`npm run prisma:migrate`)
- [ ] Service starts successfully (`./start.sh`)
- [ ] Health check passes (`curl http://localhost:5009/health`)
- [ ] API Gateway routes work (`curl http://localhost:5100/api/messaging/health`)
- [ ] Database tables created (verified in PostgreSQL)
- [ ] Frontend can connect to messaging API

## 🎉 Next Steps After Setup

1. **Test Chat Creation**: Create a test chat room via API
2. **Test Message Sending**: Send messages to chat rooms
3. **Test Agent Integration**: Create agent chat and verify Cyrex forwarding
4. **Test Real-time Updates**: Verify WebSocket connections via Realtime Gateway
5. **Frontend Integration**: Connect ChatWidget component to messaging API

---

**Status**: Ready for migration and testing! 🚀

