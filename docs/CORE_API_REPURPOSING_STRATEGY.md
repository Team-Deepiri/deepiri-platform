# Core-API Repurposing Strategy

## Overview

Instead of deprecating `deepiri-core-api`, we can **repurpose** it into valuable assets that support the microservices architecture.

## Current Assets in Core-API

### 💎 Valuable Assets

| Asset | Location | Value |
|-------|----------|-------|
| **Models** | `src/models/` | 13 Mongoose schemas (User, Task, Challenge, etc.) |
| **Business Logic** | `src/services/` | 14 service files with core business logic |
| **Middleware** | `src/middleware/` | Auth, rate limiting, sanitization, audit logging |
| **API Routes** | `src/routes/` | 15 route files with endpoint definitions |
| **Types** | `src/types/` | TypeScript type definitions |
| **Tests** | `tests/` | Jest test suite |
| **Config** | `src/config/` | Firebase, database configs |
| **Utilities** | `src/utils/` | Logging, feature flags |

## Repurposing Options

### ✅ Option 1: Shared Library Package (RECOMMENDED)

**Transform core-api into a shared library that microservices can use.**

```
deepiri-core-api/
  ↓ Transform into ↓
deepiri-shared-core/
├── models/           # Shared Mongoose schemas
├── middleware/       # Reusable middleware
├── types/           # Shared TypeScript types
├── utils/           # Common utilities
└── validators/      # Validation logic
```

**Benefits:**
- ✅ Microservices share common code
- ✅ Consistent data models across services
- ✅ DRY principle (Don't Repeat Yourself)
- ✅ Single source of truth for business logic
- ✅ Easy to version and update

**Use Cases:**
- All microservices import models from `@deepiri/shared-core`
- Common middleware (auth, rate limiting) shared across services
- Consistent validation logic
- Shared utility functions

---

### ✅ Option 2: API Contract Validator

**Use core-api as the "golden reference" to validate that microservices match the original behavior.**

```typescript
// In CI/CD pipeline
import { CoreAPIValidator } from '@deepiri/core-api-validator';

// Test that auth-service matches core-api behavior
test('auth-service matches core-api /auth/login', async () => {
  const coreResponse = await coreAPI.post('/auth/login', data);
  const microserviceResponse = await authService.post('/auth/login', data);
  expect(microserviceResponse).toMatchAPIContract(coreResponse);
});
```

**Benefits:**
- ✅ Ensures microservices don't break existing behavior
- ✅ Catches regressions during migration
- ✅ Confidence in gradual migration
- ✅ Documentation of expected behavior

---

### ✅ Option 3: Development & Testing Environment

**Keep core-api as a lightweight all-in-one option for quick local development.**

```yaml
# docker-compose.simple.yml
services:
  core-api:
    image: deepiri-core-api:latest
    ports:
      - "5000:5000"
  mongodb:
    image: mongo:7.0
  redis:
    image: redis:7.2-alpine
```

**Benefits:**
- ✅ Quick setup for new developers
- ✅ Testing without spinning up 9+ microservices
- ✅ Integration testing in single process
- ✅ Faster CI/CD for simple tests
- ✅ Backup deployment option

**Use Cases:**
- New developer onboarding
- Quick prototyping
- Integration testing
- Small-scale deployments

---

### ✅ Option 4: API Documentation Generator

**Extract OpenAPI/Swagger specs from core-api to document all APIs.**

```typescript
// core-api already has swagger-jsdoc
import swaggerJsdoc from 'swagger-jsdoc';

// Extract OpenAPI spec
const apiSpec = generateOpenAPIFromCoreAPI();

// Use for:
// - API Gateway documentation
// - Frontend TypeScript client generation
// - Postman collection generation
// - API testing
```

**Benefits:**
- ✅ Single source of truth for API contracts
- ✅ Auto-generate API documentation
- ✅ Generate TypeScript clients
- ✅ Validate microservices against spec

---

### ✅ Option 5: Migration Comparison Tool

**Run core-api and microservices side-by-side to compare behavior.**

```
┌─────────────┐
│   Request   │
└──────┬──────┘
       │
   ┌───▼────┐
   │ Proxy  │ (sends to both)
   └───┬────┘
       │
   ┌───▼────────────────┐
   │                    │
   ▼                    ▼
Core-API          Microservices
   │                    │
   └────────┬───────────┘
            │
      ┌─────▼──────┐
      │  Compare   │
      │  Responses │
      └────────────┘
```

**Benefits:**
- ✅ Validate migration correctness
- ✅ Catch edge cases
- ✅ A/B testing
- ✅ Gradual migration confidence

---

### ✅ Option 6: Canonical Models Package

**Extract just the models and types into a shared package.**

```
deepiri-models/
├── models/
│   ├── User.ts
│   ├── Task.ts
│   ├── Challenge.ts
│   └── ...
├── types/
│   └── index.ts
└── validators/
    └── schemas.ts
```

**Benefits:**
- ✅ All services use identical data models
- ✅ Consistent database schemas
- ✅ Easy to maintain and version
- ✅ Prevents schema drift

**Usage:**
```typescript
// In any microservice
import { User, Task, Challenge } from '@deepiri/models';

// Guaranteed to be using the same schema
const user = await User.findById(userId);
```

---

### ✅ Option 7: Monolithic Fallback Option

**Keep core-api as a monolithic deployment option for specific use cases.**

**Use Cases:**
- Small-scale deployments (< 100 users)
- Edge deployments (limited resources)
- Offline deployments
- Simplified hosting
- Cost-sensitive environments

**Benefits:**
- ✅ Lower infrastructure costs
- ✅ Simpler deployment
- ✅ No microservice overhead
- ✅ Option for different deployment scales

---

## Recommended Implementation Plan

### Phase 1: Extract Shared Core Library (Weeks 1-2)

1. Create new package: `platform-services/shared/deepiri-shared-core`
2. Move from core-api:
   - ✅ All models → `shared-core/models/`
   - ✅ Common middleware → `shared-core/middleware/`
   - ✅ Types → `shared-core/types/`
   - ✅ Utilities → `shared-core/utils/`
3. Update microservices to import from `@deepiri/shared-core`
4. Test all microservices

### Phase 2: API Contract Validator (Weeks 3-4)

1. Create `deepiri-api-validator` package
2. Set up contract testing in CI/CD
3. Run tests for each microservice against core-api
4. Document any differences

### Phase 3: Simplified Dev Environment (Week 5)

1. Create `docker-compose.simple.yml` with core-api
2. Document quick-start guide
3. Add to onboarding documentation

### Phase 4: Keep as Reference (Ongoing)

1. Maintain core-api for:
   - API documentation generation
   - Migration validation
   - Fallback deployment option
2. Mark as "reference implementation"
3. Keep tests updated

---

## Detailed: Shared Core Library

### Structure

```
platform-services/shared/deepiri-shared-core/
├── src/
│   ├── models/
│   │   ├── User.ts
│   │   ├── Task.ts
│   │   ├── Challenge.ts
│   │   ├── Analytics.ts
│   │   ├── Badge.ts
│   │   ├── Gamification.ts
│   │   ├── Integration.ts
│   │   ├── Notification.ts
│   │   └── index.ts
│   ├── middleware/
│   │   ├── authenticateJWT.ts
│   │   ├── rateLimit.ts
│   │   ├── sanitize.ts
│   │   ├── auditLogger.ts
│   │   └── index.ts
│   ├── types/
│   │   ├── user.types.ts
│   │   ├── task.types.ts
│   │   ├── challenge.types.ts
│   │   └── index.ts
│   ├── utils/
│   │   ├── logger.ts
│   │   ├── validators.ts
│   │   └── index.ts
│   └── index.ts
├── package.json
├── tsconfig.json
└── README.md
```

### Usage in Microservices

```typescript
// In auth-service
import { User, authenticateJWT, logger } from '@deepiri/shared-core';

// Use shared model
const user = await User.findById(userId);

// Use shared middleware
app.use(authenticateJWT);

// Use shared utilities
logger.info('User authenticated', { userId });
```

### Benefits for Each Service

| Service | Benefits from Shared Core |
|---------|--------------------------|
| auth-service | User model, auth middleware, types |
| task-orchestrator | Task model, validation, types |
| engagement-service | Gamification, Badge models |
| challenge-service | Challenge model, types |
| notification-service | Notification model, types |
| external-bridge-service | Integration model, types |
| platform-analytics-service | Analytics model, types |

---

## Comparison: Keep vs Repurpose

| Aspect | Deprecate Core-API | Repurpose Core-API |
|--------|-------------------|-------------------|
| Code Reuse | ❌ Duplicate in each service | ✅ Shared library |
| Maintenance | ❌ Update 9+ services | ✅ Update one place |
| Testing | ❌ Test each service separately | ✅ Shared tests + contract tests |
| Migration Risk | ⚠️ Higher (no reference) | ✅ Lower (can compare) |
| Dev Experience | ⚠️ Complex setup | ✅ Simple + Complex options |
| API Documentation | ❌ Manual for each service | ✅ Generated from single source |
| Deployment Options | ❌ Microservices only | ✅ Micro + Monolithic |

---

## Implementation: Shared Core Package

### 1. Create Package

```bash
cd platform-services/shared
mkdir deepiri-shared-core
cd deepiri-shared-core
npm init -y
```

### 2. Copy Assets from Core-API

```bash
# Copy models
cp -r ../../deepiri-core-api/src/models ./src/

# Copy middleware
cp -r ../../deepiri-core-api/src/middleware ./src/

# Copy types
cp -r ../../deepiri-core-api/src/types ./src/

# Copy utils
cp -r ../../deepiri-core-api/src/utils ./src/
```

### 3. Update package.json

```json
{
  "name": "@deepiri/shared-core",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "mongoose": "^8.0.3",
    "jsonwebtoken": "^9.0.2",
    "express": "^5.1.0",
    "winston": "^3.11.0"
  }
}
```

### 4. Update Microservices

```json
// In auth-service/package.json
{
  "dependencies": {
    "@deepiri/shared-core": "file:../../shared/deepiri-shared-core"
  }
}
```

---

## Timeline & Effort

| Task | Effort | Timeline |
|------|--------|----------|
| Create shared-core package | 3 days | Week 1 |
| Migrate models | 2 days | Week 1 |
| Migrate middleware | 2 days | Week 2 |
| Migrate types & utils | 2 days | Week 2 |
| Update microservices | 3 days | Week 2 |
| Testing | 2 days | Week 3 |
| Documentation | 1 day | Week 3 |
| **Total** | **15 days** | **3 weeks** |

---

## Recommendation

### 🎯 Primary: Shared Core Library

**Transform core-api into `@deepiri/shared-core` library**

**Why:**
1. ✅ Eliminates code duplication
2. ✅ Single source of truth
3. ✅ Easier maintenance
4. ✅ Consistent behavior
5. ✅ Faster development

### 🎯 Secondary: Keep as Reference

**Keep core-api for:**
1. API contract validation
2. Migration comparison
3. Documentation generation
4. Simple dev environment
5. Monolithic deployment option

### 🎯 Don't Deprecate

**Core-API is valuable - repurpose, don't delete!**

---

## Next Steps

1. **Week 1:** Create `deepiri-shared-core` package
2. **Week 2:** Migrate models and middleware
3. **Week 3:** Update all microservices to use shared-core
4. **Week 4:** Set up contract testing
5. **Week 5:** Document simplified dev workflow

## Questions to Answer

1. **Which models should be shared?**
   - Recommendation: All of them
2. **Should we keep core-api running?**
   - Recommendation: Yes, for testing and validation
3. **When can we fully sunset core-api?**
   - Recommendation: After 6 months of successful microservices operation

---

**Last Updated:** 2025-11-22

