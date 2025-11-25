# Infrastructure Team - Submodule Commands

## 🎯 Required Submodules

The Infrastructure Team needs access to:
- **deepiri-api-gateway** - API Gateway service
- **deepiri-external-bridge-service** - External integrations bridge

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri

# Pull latest changes
git pull origin main

# Initialize and update infrastructure submodules
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Update infrastructure submodules to latest
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
```

## 🔧 Working with Infrastructure Submodules

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
git commit -m "feat: add new route / improve gateway performance"

# Push to API Gateway repository
git push origin main

# Return to main repo
cd ../../..

# Update main repo to reference new submodule commit
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

### Update All Infrastructure Submodules

```bash
# From main repo root
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-external-bridge-service

# Review changes
cd platform-services/backend/deepiri-api-gateway
git log --oneline -5
cd ../../../

cd platform-services/backend/deepiri-external-bridge-service
git log --oneline -5
cd ../../../

# Commit submodule updates
git add platform-services/backend/deepiri-api-gateway
git add platform-services/backend/deepiri-external-bridge-service
git commit -m "chore: update infrastructure submodules"
git push origin main
```

### Check Submodule Status

```bash
# Check all submodules
git submodule status

# Check infrastructure submodules
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status platform-services/backend/deepiri-external-bridge-service
```

## 🐛 Troubleshooting

### Submodule Not Initialized

```bash
# If you see empty directories
git submodule update --init platform-services/backend/deepiri-api-gateway
git submodule update --init platform-services/backend/deepiri-external-bridge-service
```

### Submodule Out of Sync

```bash
# If submodule shows as modified but you haven't changed anything
cd platform-services/backend/deepiri-api-gateway
git checkout main
git pull origin main
cd ../../..
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: sync api-gateway submodule"
```

### Working on Feature Branch

```bash
# Create feature branch in submodule
cd platform-services/backend/deepiri-api-gateway
git checkout -b feature/new-routing
# ... make changes ...
git add .
git commit -m "feat: new routing feature"
git push origin feature/new-routing
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway to feature branch"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `git submodule update --init platform-services/backend/deepiri-api-gateway` | Initialize API Gateway |
| `git submodule update --init platform-services/backend/deepiri-external-bridge-service` | Initialize External Bridge |
| `git submodule update --remote platform-services/backend/deepiri-api-gateway` | Update API Gateway |
| `git submodule status` | Check all submodule statuses |

## 🔗 Related Documentation

- [Main Submodule Guide](./SUBMODULE_COMMANDS.md)
- [README](./README.md)
- [Platform Engineers Guide](./PLATFORM_ENGINEERS.md) - Similar workflow

---

**Team**: Infrastructure Team  
**Primary Submodules**: 
- `platform-services/backend/deepiri-api-gateway`
- `platform-services/backend/deepiri-external-bridge-service`  
**Repositories**: 
- `git@github.com:Team-Deepiri/deepiri-api-gateway.git`
- `git@github.com:Team-Deepiri/deepiri-external-bridge-service.git`

