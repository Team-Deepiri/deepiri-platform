# Shared Utils Architecture

## Overview

This document describes the architecture for shared utilities across Deepiri microservices.

## Current Implementation

### Service-Level Utils

Each service has its own `utils/logger.js` file that provides logging functionality. This approach:

- ✅ Works immediately with Docker builds
- ✅ No dependency management complexity
- ✅ Each service is self-contained
- ❌ Code duplication
- ❌ Updates require changes in multiple places

### Shared Utils Package

Located at `platform-services/shared/deepiri-shared-utils/`, this package provides:

- Logger factory function
- Common utilities (to be expanded)

## Long-Term Solutions

### Option 1: Monorepo with Workspaces

Use npm workspaces or yarn workspaces to manage shared code:

```json
{
  "workspaces": [
    "platform-services/backend/*",
    "platform-services/shared/deepiri-shared-utils"
  ]
}
```

**Pros:**
- Single source of truth
- Easy to update shared code
- TypeScript support across packages

**Cons:**
- Requires workspace setup
- Docker builds need adjustment

### Option 2: Published npm Package

Publish `@deepiri/shared-utils` to npm (private or public):

```bash
npm publish @deepiri/shared-utils
```

**Pros:**
- Version management
- Can be used in other projects
- Standard npm workflow

**Cons:**
- Requires npm registry setup
- Version updates need publishing

### Option 3: Git Submodule

Use git submodules to share code:

```bash
git submodule add <repo-url> platform-services/shared/deepiri-shared-utils
```

**Pros:**
- Version control
- Can be in separate repo

**Cons:**
- Git submodule complexity
- Team coordination needed

### Option 4: Docker Multi-Stage Build with Shared Layer

Create a base Docker image with shared utilities:

```dockerfile
FROM node:18-alpine AS shared-utils
WORKDIR /shared
COPY platform-services/shared/deepiri-shared-utils ./
RUN npm install

FROM node:18-alpine
COPY --from=shared-utils /shared /app/shared-utils
```

**Pros:**
- Optimized Docker builds
- Shared layer caching

**Cons:**
- Docker complexity
- Still need npm package structure

## Recommended Approach

For now, we use **Option 1 (Service-Level Utils)** with a plan to migrate to **Monorepo with Workspaces**:

1. **Phase 1 (Current)**: Each service has its own utils
2. **Phase 2**: Create shared-utils package and use npm workspaces
3. **Phase 3**: Update Dockerfiles to support workspace dependencies
4. **Phase 4**: Migrate services to use shared package

## Migration Plan

### Step 1: Set up Workspaces

Update root `package.json`:

```json
{
  "name": "deepiri",
  "private": true,
  "workspaces": [
    "platform-services/backend/*",
    "platform-services/shared/deepiri-shared-utils"
  ]
}
```

### Step 2: Update Service package.json

Add shared-utils as a dependency:

```json
{
  "dependencies": {
    "@deepiri/shared-utils": "*"
  }
}
```

### Step 3: Update Service Code

Change imports:

```javascript
// Before
const logger = require('../../utils/logger');

// After
const { createLogger } = require('@deepiri/shared-utils');
const logger = createLogger('service-name');
```

### Step 4: Update Dockerfiles

Ensure workspace dependencies are installed:

```dockerfile
COPY package*.json ./
COPY platform-services/shared/deepiri-shared-utils ./platform-services/shared/deepiri-shared-utils
RUN npm install --workspace=platform-services/shared/deepiri-shared-utils
```

## Best Practices

1. **Keep utilities generic**: Don't add service-specific logic
2. **Version utilities**: Use semantic versioning
3. **Documentation**: Keep README updated
4. **Testing**: Add tests for shared utilities
5. **Backward compatibility**: Maintain compatibility during migration

## Utilities to Add

- [ ] Error handling utilities
- [ ] Validation helpers
- [ ] Common middleware (auth, rate limiting)
- [ ] Database connection helpers
- [ ] API client utilities
- [ ] Configuration helpers
- [ ] Health check utilities



