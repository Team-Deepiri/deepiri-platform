# Platform Engineers - Submodule Commands

## 🎯 Required Submodules

Platform Engineers need access to **ALL** submodules for platform management:
- **diri-cyrex** - AI/ML service
- **deepiri-core-api** - Main backend API
- **deepiri-web-frontend** - Frontend application
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

# Initialize and update ALL submodules (Platform Engineers manage everything)
git submodule update --init --recursive
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Update ALL submodules to latest
git submodule update --remote --recursive
```

## 🔧 Working with All Submodules

### Update All Submodules

```bash
# Update all submodules at once
git submodule update --remote --recursive

# Review what changed
git submodule status

# Commit all updates
git add .
git commit -m "chore: update all submodules"
git push origin main
```

### Update Specific Submodule

```bash
# Update a specific service
git submodule update --remote deepiri-core-api

# Or update multiple specific ones
git submodule update --remote deepiri-core-api platform-services/backend/deepiri-api-gateway
```

### Check All Submodule Statuses

```bash
# Check all submodules
git submodule status

# Get detailed status for each
git submodule foreach 'echo "=== $name ===" && git status && echo ""'
```

### Synchronize All Submodules

```bash
# Sync all submodules to their main branches
git submodule foreach 'git checkout main && git pull origin main'

# Commit sync
git add .
git commit -m "chore: sync all submodules to main"
git push origin main
```

## 🔧 Platform Management Tasks

### Deploy All Services

```bash
# Ensure all submodules are up to date
git submodule update --remote --recursive

# Build and deploy
docker compose -f docker-compose.platform-engineers.yml build
docker compose -f docker-compose.platform-engineers.yml up -d
```

### Update Service Configuration

```bash
# Update API Gateway config
cd platform-services/backend/deepiri-api-gateway
# ... edit config ...
git add .
git commit -m "chore: update gateway configuration"
git push origin main
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway submodule"
git push origin main
```

### Monitor Submodule Health

```bash
# Check if any submodules are behind
git submodule foreach 'echo "$name: $(git rev-parse HEAD) vs $(git rev-parse origin/main)"'

# Check for uncommitted changes
git submodule foreach 'if [ -n "$(git status --porcelain)" ]; then echo "$name has uncommitted changes"; fi'
```

## 🐛 Troubleshooting

### Submodule Not Initialized

```bash
# Initialize all submodules
git submodule update --init --recursive
```

### Submodule Out of Sync

```bash
# Sync all submodules
git submodule foreach 'git checkout main && git pull origin main'
git add .
git commit -m "chore: sync all submodules"
```

### Working on Platform Feature

```bash
# Update multiple submodules for a platform feature
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service

# Review changes
cd platform-services/backend/deepiri-api-gateway
git log --oneline -5
cd ../../../

# Commit updates
git add platform-services/backend/deepiri-api-gateway
git add platform-services/backend/deepiri-auth-service
git commit -m "chore: update platform services for new feature"
git push origin main
```

### Clean Platform Environment

```bash
# Reset all submodules to clean state
git submodule foreach 'git clean -fd && git reset --hard HEAD'
git submodule update --init --recursive
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `git submodule update --init --recursive` | Initialize all submodules |
| `git submodule update --remote --recursive` | Update all submodules |
| `git submodule status` | Check all submodule statuses |
| `git submodule foreach 'git status'` | Check status of each submodule |
| `git submodule foreach 'git pull'` | Pull latest in all submodules |
| `git submodule foreach 'git checkout main'` | Checkout main in all submodules |

## 🔧 Platform-Specific Commands

### Update Infrastructure Services

```bash
# Update all infrastructure-related submodules
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service
git submodule update --remote platform-services/backend/deepiri-external-bridge-service

git add platform-services/backend/
git commit -m "chore: update infrastructure services"
git push origin main
```

### Update Application Services

```bash
# Update application services
git submodule update --remote deepiri-core-api
git submodule update --remote deepiri-web-frontend

git add deepiri-core-api deepiri-web-frontend
git commit -m "chore: update application services"
git push origin main
```

### Full Platform Update

```bash
# Update everything
git pull origin main
git submodule update --remote --recursive
git add .
git commit -m "chore: full platform update"
git push origin main
```

## 🔗 Related Documentation

- [Main Submodule Guide](./SUBMODULE_COMMANDS.md)
- [README](./README.md)
- [Infrastructure Team Guide](./INFRASTRUCTURE_TEAM.md)
- [Backend Team Guide](./BACKEND_TEAM.md)

---

**Team**: Platform Engineers  
**Required Submodules**: **ALL** (for platform management)  
**Repositories**: All team repositories  
**Responsibilities**: Platform stability, deployments, infrastructure management

