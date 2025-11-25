# Backend Team - Submodule Commands

## 🎯 Required Submodules

The Backend Team needs access to:
- **deepiri-core-api** - Main backend API
- **deepiri-api-gateway** - API Gateway service
- **deepiri-auth-service** - Authentication service
- **deepiri-external-bridge-service** - External integrations bridge

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri

# Pull latest changes
git pull origin main

# Initialize and update all backend submodules
git submodule update --init --recursive deepiri-core-api
git submodule update --init --recursive deepiri-web-frontend
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
git submodule update --init --recursive platform-services/backend/deepiri-auth-service
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Update all backend submodules to latest
git submodule update --remote deepiri-core-api
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
```

## 🔧 Working with Backend Submodules

### Make Changes to Core API

```bash
# Navigate to Core API submodule
cd deepiri-core-api

# Check current branch
git status

# Make your changes
# ... edit files in src/ ...

# Commit changes
git add .
git commit -m "feat: add new endpoint / improve performance"

# Push to Core API repository
git push origin main

# Return to main repo
cd ..

# Update main repo
git add deepiri-core-api
git commit -m "chore: update core-api submodule"
git push origin main
```

### Make Changes to Auth Service

```bash
# Navigate to Auth Service submodule
cd platform-services/backend/deepiri-auth-service

# Check current branch
git status

# Make your changes (auth logic, JWT, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: improve authentication flow"

# Push to Auth Service repository
git push origin main

# Return to main repo
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-auth-service
git commit -m "chore: update auth-service submodule"
git push origin main
```

### Make Changes to API Gateway

```bash
# Navigate to API Gateway submodule
cd platform-services/backend/deepiri-api-gateway

# Check current branch
git status

# Make your changes (routing, middleware, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: add new route / improve gateway"

# Push to API Gateway repository
git push origin main

# Return to main repo
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway submodule"
git push origin main
```

### Make Changes to External Bridge Service

```bash
# Navigate to External Bridge submodule
cd platform-services/backend/deepiri-external-bridge-service

# Check current branch
git status

# Make your changes (integrations, webhooks, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: add new external integration"

# Push to External Bridge repository
git push origin main

# Return to main repo
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-external-bridge-service
git commit -m "chore: update external-bridge submodule"
git push origin main
```

### Update All Backend Submodules

```bash
# From main repo root - update all at once
git submodule update --remote deepiri-core-api
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service
git submodule update --remote platform-services/backend/deepiri-external-bridge-service

# Commit all updates
git add deepiri-core-api
git add platform-services/backend/deepiri-api-gateway
git add platform-services/backend/deepiri-auth-service
git add platform-services/backend/deepiri-external-bridge-service
git commit -m "chore: update all backend submodules"
git push origin main
```

### Check Submodule Status

```bash
# Check all submodules
git submodule status

# Check specific backend submodules
git submodule status deepiri-core-api
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status platform-services/backend/deepiri-auth-service
git submodule status platform-services/backend/deepiri-external-bridge-service
```

## 🐛 Troubleshooting

### Submodule Not Initialized

```bash
# Initialize all backend submodules
git submodule update --init --recursive deepiri-core-api
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
git submodule update --init --recursive platform-services/backend/deepiri-auth-service
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
```

### Submodule Out of Sync

```bash
# Sync a specific submodule
cd deepiri-core-api
git checkout main
git pull origin main
cd ..
git add deepiri-core-api
git commit -m "chore: sync core-api submodule"
```

### Working on Feature Branch

```bash
# Create feature branch in submodule
cd deepiri-core-api
git checkout -b feature/new-endpoint
# ... make changes ...
git add .
git commit -m "feat: new endpoint"
git push origin feature/new-endpoint
cd ..

# Update main repo
git add deepiri-core-api
git commit -m "chore: update core-api to feature branch"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `git submodule update --init --recursive deepiri-core-api` | Initialize Core API |
| `git submodule update --remote deepiri-core-api` | Update Core API |
| `git submodule status` | Check all submodule statuses |
| `git submodule update --remote` | Update all submodules |

## 🔗 Related Documentation

- [Main Submodule Guide](./SUBMODULE_COMMANDS.md)
- [README](./README.md)
- [Infrastructure Team Guide](./INFRASTRUCTURE_TEAM.md) - Similar workflow

---

**Team**: Backend Team  
**Primary Submodules**: 
- `deepiri-core-api`
- `platform-services/backend/deepiri-api-gateway`
- `platform-services/backend/deepiri-auth-service`
- `platform-services/backend/deepiri-external-bridge-service`  
**Repositories**: 
- `git@github.com:Team-Deepiri/deepiri-core-api.git`
- `git@github.com:Team-Deepiri/deepiri-api-gateway.git`
- `git@github.com:Team-Deepiri/deepiri-auth-service.git`
- `git@github.com:Team-Deepiri/deepiri-external-bridge-service.git`

