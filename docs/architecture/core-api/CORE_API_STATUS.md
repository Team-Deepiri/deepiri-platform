# Core API Status and Frontend Team Access

## Quick Answers

### 1. Do we need to give the frontend team the core-api?

**NO** ❌ - The frontend team does **NOT** need access to `deepiri-core-api`.

**Why:**
- Frontend connects to the **API Gateway** at `http://localhost:5000/api`
- The API Gateway routes all requests to the new microservices
- Core-api is deprecated and being replaced by microservices
- Frontend only needs to know the API Gateway endpoints

### 2. Is the core-api just old or is it still important?

**It's BEING REPURPOSED** 🔄 - Core-api has valuable assets that shouldn't be thrown away!

**New Strategy:**
- ✅ **Repurpose:** Transform into shared library (`@deepiri/shared-core`)
- ✅ **Keep:** Maintain as API contract validator
- ✅ **Use:** Simple dev environment option
- 📦 **Assets:** Models, middleware, business logic, types

**See:** [CORE_API_REPURPOSING_STRATEGY.md](CORE_API_REPURPOSING_STRATEGY.md) for details

---

## Architecture Overview

### Current (Microservices) ✅
```
Frontend (5173)
    ↓
API Gateway (5000)
    ↓
┌─────────────────────────────────────┐
│  Microservices (platform-services)  │
├─────────────────────────────────────┤
│  • auth-service (5001)             │
│  • task-orchestrator (5002)         │
│  • engagement-service (5003)        │
│  • platform-analytics (5004)        │
│  • notification-service (5005)       │
│  • external-bridge (5006)           │
│  • challenge-service (5007)          │
│  • realtime-gateway (5008)          │
│  • cyrex (8000)                      │
└─────────────────────────────────────┘
```

### Future (Repurposed) 🔄
```
Core-API Assets
    ↓
┌─────────────────────────┐
│  @deepiri/shared-core   │ ← Shared library
├─────────────────────────┤
│  • Models               │
│  • Middleware           │
│  • Types                │
│  • Business Logic       │
└─────────────────────────┘
    ↓
All microservices import from shared-core
```

---

## Frontend Team Requirements

### ✅ What Frontend Team Needs:

1. **API Gateway Access** (Required)
   - Service: `platform-services/backend/deepiri-api-gateway`
   - URL: `http://localhost:5000/api`
   - Purpose: All API calls go through this gateway

2. **Frontend Codebase** (Required)
   - Service: `deepiri-web-frontend`
   - Purpose: Their main work area

3. **API Documentation** (Recommended)
   - Service endpoint documentation
   - API Gateway routing rules
   - Request/response schemas

### ❌ What Frontend Team Does NOT Need:

1. **Core-API** - Deprecated, not used
2. **Individual Microservices** - They go through API Gateway
3. **Backend Implementation Details** - They only need API contracts

---

## Core-API Repurposing Status

### Valuable Assets Being Repurposed ✅

| Asset | Current Location (core-api) | Future Use |
|-------|----------------------------|------------|
| **Models** | `src/models/*.ts` (13 files) | → `@deepiri/shared-core/models` |
| **Middleware** | `src/middleware/*.ts` (7 files) | → `@deepiri/shared-core/middleware` |
| **Types** | `src/types/*.ts` | → `@deepiri/shared-core/types` |
| **Business Logic** | `src/services/*.ts` (14 files) | → Reference & shared utilities |
| **Validators** | Throughout codebase | → `@deepiri/shared-core/validators` |
| **Tests** | `tests/*.test.js` | → Contract testing & shared tests |
| **API Routes** | `src/routes/*.ts` (15 files) | → API documentation generation |

### New Purposes for Core-API 🎯

1. **Shared Core Library** - Extract common code into `@deepiri/shared-core`
2. **API Contract Validator** - Ensure microservices match original behavior
3. **Dev Environment** - Quick all-in-one setup for new developers
4. **Documentation Source** - Generate OpenAPI specs
5. **Migration Validator** - Compare behavior during migration
6. **Fallback Option** - Monolithic deployment for specific use cases

**See:** [CORE_API_REPURPOSING_STRATEGY.md](CORE_API_REPURPOSING_STRATEGY.md)

---

## Who Needs Core-API Access?

### ✅ Teams That WILL Need It:

1. **Backend Team** (Primary users)
   - Creating `@deepiri/shared-core` library
   - Extracting models and middleware
   - Ensuring microservices use shared code

2. **Platform Engineers** (Important users)
   - Setting up shared library infrastructure
   - Contract testing setup
   - CI/CD integration

3. **Infrastructure Team** (Reference users)
   - Simple dev environment setup
   - Deployment options
   - Fallback configurations

4. **All Microservice Developers** (Indirect users)
   - Will import from `@deepiri/shared-core`
   - Use shared models and middleware
   - Benefit from shared utilities

### ❌ Teams That Do NOT Need Direct Access:

1. **Frontend Team** ❌
   - Uses API Gateway only
   - Benefits indirectly from consistent models

2. **AI/ML Team** ❌
   - Works with `diri-cyrex` service
   - May use shared types if needed

3. **QA Team** ❌ (mostly)
   - Tests against API Gateway
   - May use for contract testing

---

## Frontend API Integration

### Current Frontend Setup:

```typescript
// Frontend uses API Gateway
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

// All API calls go through gateway
axios.get(`${API_BASE_URL}/auth/login`)
axios.get(`${API_BASE_URL}/tasks`)
axios.get(`${API_BASE_URL}/challenges`)
```

### API Gateway Routes:

The API Gateway (`platform-services/backend/deepiri-api-gateway`) handles:
- `/api/auth/*` → `auth-service:5001`
- `/api/tasks/*` → `task-orchestrator:5002`
- `/api/engagement/*` → `engagement-service:5003`
- `/api/analytics/*` → `platform-analytics-service:5004`
- `/api/notifications/*` → `notification-service:5005`
- `/api/integrations/*` → `external-bridge-service:5006`
- `/api/challenges/*` → `challenge-service:5007`
- `/api/realtime/*` → `realtime-gateway:5008`
- `/api/cyrex/*` → `cyrex:8000`

---

## Recommendations

### For Frontend Team:

1. **Use API Gateway Only**
   - All requests to `http://localhost:5000/api`
   - Don't call microservices directly
   - Gateway handles routing, auth, rate limiting

2. **API Documentation**
   - Request API endpoint documentation
   - Get OpenAPI/Swagger specs if available
   - Understand request/response formats

3. **No Core-API Access Needed**
   - Core-api is internal implementation detail
   - Frontend doesn't need to see backend code
   - API Gateway provides clean interface

### For Project Management:

1. **Implement Shared Library**
   - Create `@deepiri/shared-core` package
   - Extract models, middleware, types from core-api
   - Update all microservices to use shared-core

2. **Keep Core-API for Reference**
   - Use for API contract validation
   - Maintain for simple dev environment
   - Keep as documentation source

3. **Clear API Contracts**
   - Document all API Gateway endpoints
   - Generate OpenAPI/Swagger from core-api
   - Maintain backward compatibility

**Timeline:** 3-4 weeks for shared library implementation

---

## Summary

| Question | Answer |
|----------|--------|
| **Frontend needs core-api?** | ❌ NO - They use API Gateway only |
| **Core-api still important?** | ✅ YES - Being repurposed into shared library |
| **What frontend needs?** | ✅ API Gateway access + API documentation |
| **Who needs core-api?** | Backend team (shared library), All devs (indirect use) |
| **What happens to core-api?** | 🔄 Transform into `@deepiri/shared-core` + keep as reference |

---

**Last Updated:** 2025-11-22

