# MongoDB to PostgreSQL Migration Guide

## Overview

This document outlines the complete migration from MongoDB to PostgreSQL for the Deepiri platform. This migration is part of the **Minimal Setup for Early Stage / Cheap Deployment** strategy.

## Infrastructure Changes Completed ✅

### Docker Compose Files
All three main docker-compose files have been updated:
- ✅ `docker-compose.dev.yml`
- ✅ `docker-compose.backend-team.yml`
- ✅ `docker-compose.platform-engineers.yml`

**Changes:**
- Removed MongoDB (mongo:7.0) and Mongo Express containers
- Added PostgreSQL (postgres:16-alpine) and pgAdmin containers
- Updated all service environment variables from `MONGO_URI` to `DATABASE_URL`
- Updated all service dependencies from `mongodb` to `postgres`
- Replaced MongoDB volumes with PostgreSQL volumes

### Environment Variables
- ✅ `MONGO_URI` → `DATABASE_URL`
- ✅ `MONGO_ROOT_USER` → `POSTGRES_USER`
- ✅ `MONGO_ROOT_PASSWORD` → `POSTGRES_PASSWORD`
- ✅ `MONGO_DB` → `POSTGRES_DB`
- ✅ Added `PGADMIN_EMAIL` and `PGADMIN_PASSWORD`

### Kubernetes ConfigMaps
Updated all K8s configmaps:
- ✅ auth-service-configmap.yaml
- ✅ task-orchestrator-configmap.yaml
- ✅ engagement-service-configmap.yaml
- ✅ platform-analytics-service-configmap.yaml
- ✅ notification-service-configmap.yaml
- ✅ external-bridge-service-configmap.yaml
- ✅ challenge-service-configmap.yaml

### Documentation
- ✅ Updated README.md
- ✅ Updated ENVIRONMENT_VARIABLES.md
- ✅ Updated RUN_DEV_GUIDE.md
- ✅ Updated ops/k8s/README.md
- ✅ Updated all team environment READMEs
- ✅ Updated QUICK_START.md

### Startup Scripts
- ✅ Updated all Python run.py scripts
- ✅ Updated all shell scripts (.sh)
- ✅ Updated all PowerShell scripts (.ps1)

### Database Schema
- ✅ Created `scripts/postgres-init.sql` with complete PostgreSQL schema

## Backend Services Migration 🔄

The following backend services need to be updated to use PostgreSQL instead of Mongoose/MongoDB:

### 1. Auth Service (`platform-services/backend/deepiri-auth-service`)

**Files to Update:**

#### `package.json`
Replace:
```json
"mongoose": "^x.x.x"
```

With:
```json
"pg": "^8.11.3",
"@types/pg": "^8.10.9"
```

Or use an ORM like:
```json
"sequelize": "^6.35.0",
"sequelize-typescript": "^2.1.5",
"pg": "^8.11.3",
"pg-hstore": "^2.3.4"
```

Or Prisma:
```json
"@prisma/client": "^5.7.0"
```

#### `src/server.ts`
Replace:
```typescript
import mongoose from 'mongoose';

const MONGO_URI: string = process.env.MONGO_URI || 'mongodb://mongodb:27017/deepiri';
mongoose.connect(MONGO_URI)
  .then(() => secureLog('info', 'Auth Service: Connected to MongoDB'))
  .catch((err: Error) => secureLog('error', 'Auth Service: MongoDB connection error', err));
```

With (using pg):
```typescript
import { Pool } from 'pg';

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://deepiri:deepiripassword@postgres:5432/deepiri';
export const pool = new Pool({ connectionString: DATABASE_URL });

pool.connect()
  .then(() => secureLog('info', 'Auth Service: Connected to PostgreSQL'))
  .catch((err: Error) => secureLog('error', 'Auth Service: PostgreSQL connection error', err));
```

#### `src/authService.ts`
Replace Mongoose models with PostgreSQL queries or an ORM.

**Before (Mongoose):**
```typescript
const UserSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  name: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

const User = mongoose.models.User || mongoose.model('User', UserSchema);

// Query example
const user = await User.findOne({ email });
```

**After (using pg):**
```typescript
import { pool } from './server';

// Query example
const result = await pool.query(
  'SELECT * FROM users WHERE email = $1',
  [email]
);
const user = result.rows[0];

// Insert example
await pool.query(
  'INSERT INTO users (email, password, name) VALUES ($1, $2, $3) RETURNING *',
  [email, hashedPassword, name]
);
```

#### `src/skillTreeService.ts`
Similar changes - replace Mongoose models with PostgreSQL queries for:
- `SkillTree` model → `skill_trees` table
- Skills embedded documents → `skills` table with foreign keys

#### `src/socialGraphService.ts`
- `SocialConnection` model → `social_connections` table

#### `src/timeSeriesService.ts`
- `ProgressPoint` model → `progress_points` table

### 2. Task Orchestrator (`platform-services/backend/deepiri-task-orchestrator`)

**Files to Update:**

#### `src/taskVersioningService.ts`
- `TaskVersion` model → `task_versions` table

#### `src/dependencyGraphService.ts`
- `TaskDependency` model → `task_dependencies` table

### 3. Engagement Service (`platform-services/backend/deepiri-engagement-service`)

**Files to Update:**

#### `src/models/` directory
Replace all Mongoose models:
- `Momentum.ts` → Use `momentum` table
- `Streak.ts` → Use `streaks` table
- `Boost.ts` → Use `boosts` table
- `Objective.ts` → Use `objectives` table
- `Odyssey.ts` → Use `odysseys` table
- `Season.ts` → Use `seasons` table
- `Reward.ts` → Use `rewards` table

### 4. Notification Service

- Notifications model → `notifications` table
- Push subscriptions → `push_subscriptions` table

### 5. External Bridge Service

- Webhooks model → `webhooks` table
- Webhook logs → `webhook_logs` table

### 6. Challenge Service

- Challenges model → `challenges` table
- Challenge participants → `challenge_participants` table

### 7. Platform Analytics Service

- Analytics events → `analytics_events` table

## Migration Strategy Options

### Option 1: Native pg Driver (Lightweight)
**Pros:**
- Minimal dependencies
- Fast and lightweight
- Full control over SQL

**Cons:**
- More boilerplate code
- Manual SQL query writing
- No automatic type safety

**Install:**
```bash
npm install pg @types/pg
```

### Option 2: Sequelize ORM (Popular)
**Pros:**
- Similar to Mongoose in terms of API
- Good documentation
- TypeScript support
- Migrations built-in

**Cons:**
- Heavier than native pg
- Some performance overhead
- Learning curve for migrations

**Install:**
```bash
npm install sequelize sequelize-typescript pg pg-hstore
npm install --save-dev @types/node
```

### Option 3: Prisma (Modern)
**Pros:**
- Excellent TypeScript support
- Auto-generated types
- Great developer experience
- Built-in migration system

**Cons:**
- Requires code generation step
- Opinionated structure
- Slightly heavier

**Install:**
```bash
npm install @prisma/client
npm install --save-dev prisma
npx prisma init --datasource-provider postgresql
```

## Recommended Approach

For minimal deployment and easier migration, I recommend **Prisma** because:
1. It has the best TypeScript support
2. Schema is declarative and easy to maintain
3. Migrations are automatic
4. It's modern and well-maintained
5. The learning curve is gentle

## Next Steps

1. **Choose your database library** (pg, Sequelize, or Prisma)
2. **Update package.json** for each service
3. **Migrate models to PostgreSQL**
   - Use the schema in `scripts/postgres-init.sql` as reference
   - Convert Mongoose schemas to your chosen ORM/query format
4. **Update all database queries**
5. **Test each service individually**
6. **Update integration tests**

## Database Comparison

### Before (MongoDB)
```
📦 MongoDB Setup
├── Port: 27017
├── UI: Mongo Express (8081)
├── Schema: Flexible, document-based
└── Queries: MongoDB query language
```

### After (PostgreSQL)
```
📦 PostgreSQL Setup
├── Port: 5432
├── UI: pgAdmin (5050)
├── Schema: Structured, relational
└── Queries: SQL
```

## Deployment Infrastructure

### Current Setup (Minimal for Early Stage) ✅

```
┌─────────────────────────────────────────┐
│  PostgreSQL (1 instance)                │
│  → Users, roles, tasks, quests,         │
│     objectives, momentum, streaks       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Redis (1 instance)                     │
│  → Temporary boosts, real-time stats    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Blob Storage (MinIO/S3/GCP)            │
│  → AI-generated assets                  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Optional: InfluxDB                     │
│  → Time-series analytics                │
└─────────────────────────────────────────┘
```

**Note:** MongoDB is no longer part of the infrastructure and can be scaled in later if document storage for AI assets becomes necessary.

## Migration Checklist

- [x] Update docker-compose files
- [x] Update environment variables
- [x] Update K8s configmaps
- [x] Update documentation
- [x] Update startup scripts
- [x] Create PostgreSQL schema
- [ ] Update auth-service code
- [ ] Update task-orchestrator code
- [ ] Update engagement-service code
- [ ] Update notification-service code
- [ ] Update external-bridge-service code
- [ ] Update challenge-service code
- [ ] Update platform-analytics-service code
- [ ] Write data migration scripts (if existing data)
- [ ] Update integration tests
- [ ] Update e2e tests

## Support

For questions or issues during migration:
1. Check the PostgreSQL schema in `scripts/postgres-init.sql`
2. Review the database documentation in `ENVIRONMENT_VARIABLES.md`
3. Test locally with `docker-compose up postgres pgadmin`
4. Access pgAdmin at http://localhost:5050 (credentials in .env)

## Benefits of This Migration

1. **Cost Savings**: PostgreSQL is free and has lower operational costs
2. **Simplicity**: One relational database is easier to manage than multiple DBs
3. **Performance**: PostgreSQL is excellent for structured data
4. **Scalability**: Can scale vertically easily, and horizontally when needed
5. **ACID Compliance**: Better data consistency guarantees
6. **Rich Ecosystem**: Excellent tooling, ORMs, and community support
7. **Deployment**: Easier to deploy with managed PostgreSQL services (AWS RDS, GCP Cloud SQL, etc.)

## MinIO for Blob Storage

MinIO is already configured in the docker-compose files and will handle:
- AI-generated images
- User avatars
- Document attachments
- Video content
- Any other large binary assets

Access MinIO:
- API: http://localhost:9000
- Console: http://localhost:9001
- Credentials: Set via `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`

