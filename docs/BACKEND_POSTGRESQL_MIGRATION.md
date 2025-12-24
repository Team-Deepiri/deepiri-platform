# Backend PostgreSQL Migration Guide

## Status: IN PROGRESS

This document tracks the migration of all backend services from MongoDB/Mongoose to PostgreSQL/Prisma.

---

## ✅ Completed Services

### 1. Auth Service (`deepiri-auth-service`)
- ✅ Prisma schema created
- ✅ Package.json updated (mongoose → @prisma/client)
- ✅ Database connection (db.ts) created
- ✅ server.ts updated
- ✅ authService.ts migrated
- ✅ skillTreeService.ts migrated
- ✅ socialGraphService.ts migrated
- ✅ timeSeriesService.ts migrated

**Next Steps:**
- Run `npx prisma generate` in the service directory
- Run `npx prisma migrate dev` to create migrations
- Test all endpoints

---

## 🔄 In Progress

### 2. Task Orchestrator Service (`deepiri-task-orchestrator`)
- ⚠️ Needs Prisma schema
- ⚠️ Needs package.json update
- ⚠️ Needs service migration

---

## 📋 Remaining Services

### 3. Engagement Service (`deepiri-engagement-service`)
- ⚠️ Needs migration

### 4. Notification Service (`deepiri-notification-service`)
- ⚠️ Needs migration

### 5. External Bridge Service (`deepiri-external-bridge-service`)
- ⚠️ Needs migration

### 6. Challenge Service (`deepiri-challenge-service`)
- ⚠️ Needs migration

### 7. Platform Analytics Service (`deepiri-platform-analytics-service`)
- ⚠️ Needs migration

---

## 📝 Migration Steps for Each Service

1. **Create Prisma Schema**
   - Create `prisma/schema.prisma` file
   - Define all models based on existing Mongoose schemas
   - Map MongoDB ObjectId to PostgreSQL UUID

2. **Update package.json**
   - Remove `mongoose`
   - Add `@prisma/client` and `prisma` (dev dependency)

3. **Create Database Connection**
   - Create `src/db.ts` with Prisma client
   - Export singleton Prisma instance

4. **Update server.ts**
   - Remove mongoose imports
   - Replace mongoose.connect with Prisma connection
   - Import and call connectDatabase()

5. **Migrate Service Files**
   - Replace Mongoose models with Prisma queries
   - Update findOne → findUnique/findFirst
   - Update find → findMany
   - Update save() → create/update
   - Update populate → include
   - Update ObjectId → UUID strings

6. **Run Prisma Commands**
   ```bash
   npx prisma generate
   npx prisma migrate dev --name init
   ```

---

## 🔧 Common Patterns

### Mongoose → Prisma

**Connection:**
```typescript
// Before (Mongoose)
mongoose.connect(MONGO_URI)

// After (Prisma)
import { connectDatabase } from './db';
connectDatabase();
```

**Find One:**
```typescript
// Before
const user = await User.findOne({ email });

// After
const user = await prisma.user.findUnique({ where: { email } });
```

**Find Many:**
```typescript
// Before
const users = await User.find({ status: 'active' });

// After
const users = await prisma.user.findMany({ where: { status: 'active' } });
```

**Create:**
```typescript
// Before
const user = new User({ email, name });
await user.save();

// After
const user = await prisma.user.create({ data: { email, name } });
```

**Update:**
```typescript
// Before
await User.updateOne({ _id: id }, { name: 'New Name' });

// After
await prisma.user.update({ where: { id }, data: { name: 'New Name' } });
```

**Populate:**
```typescript
// Before
const user = await User.findById(id).populate('skillTree');

// After
const user = await prisma.user.findUnique({
  where: { id },
  include: { skillTree: true }
});
```

---

## 📊 Database Schema Mapping

The PostgreSQL schema is already defined in `deepiri/scripts/postgres-init.sql`. The Prisma schemas should match these tables:

- `users` → User model
- `skill_trees` → SkillTree model
- `skills` → Skill model
- `social_connections` → SocialConnection model
- `progress_points` → ProgressPoint model
- `tasks` → Task model
- `task_versions` → TaskVersion model
- `task_dependencies` → TaskDependency model
- And more...

---

## 🚀 Next Steps

1. Complete task-orchestrator migration
2. Migrate engagement-service
3. Migrate remaining services
4. Test all services end-to-end
5. Update documentation

---

**Last Updated:** 2025-01-29

