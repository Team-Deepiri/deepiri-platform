# QA Team - Submodule Commands

## 🎯 Required Submodules

The QA Team needs access to **ALL** submodules for comprehensive testing:
- **diri-cyrex** - AI/ML service
- **platform-services/backend/** - Backend microservices
- **deepiri-web-frontend** - Frontend application
- **deepiri-api-gateway** - API gateway entrypoint
- **deepiri-auth-service** - Authentication service
- **deepiri-external-bridge-service** - External integrations bridge

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri-platform

# Set up Git hooks (REQUIRED - protects main/master and branches containing team-dev)
./setup-hooks.sh

# Pull latest changes
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/qa-team/pull_submodules.sh

# OR manually initialize and update ALL submodules (QA needs everything)
git submodule update --init --recursive
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/qa-team/pull_submodules.sh

# OR manually update ALL submodules to latest
git submodule update --remote --recursive
```

## 🔧 Working with Submodules for Testing

### Update All Submodules

```bash
# Update all submodules at once
git submodule update --remote --recursive

# Review what changed
git submodule status

# Commit all updates
git add .
git commit -m "chore: update all submodules for QA testing"
git push origin main
```

### Test Specific Service

```bash
# Test API Gateway
cd platform-services/backend/deepiri-api-gateway
npm test
cd ..

# Test Frontend
cd deepiri-web-frontend
npm test
cd ..

# Test AI Service
cd diri-cyrex
pytest
cd ..
```

### Check All Submodule Statuses

```bash
# Check all submodules
git submodule status

# Get detailed status
git submodule foreach 'echo "=== $name ===" && git status'
```

### Update Specific Submodule for Testing

```bash
# Update only the service you're testing
git submodule update --remote platform-services/backend/deepiri-api-gateway

# Or update multiple specific ones
git submodule update --remote platform-services/backend/deepiri-api-gateway deepiri-web-frontend
```

## 🌿 Branch Naming Convention (For Test Branches)

**When creating test branches, use:**
- **Test Features**: `firstname_lastname/test/feature_name`
- **Test Bug Fixes**: `firstname_lastname/test/bug_fix_name`

**Examples:**
- `john_doe/test/integration-tests`
- `jane_smith/test/e2e-authentication`

**Note**: QA team typically works with branches created by other teams, but if you need to create test-specific branches, use the naming convention above.

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

### Working on Test Branch

```bash
# Update to specific branch for testing
cd platform-services/backend/deepiri-api-gateway
git checkout firstname_lastname/feature/some-feature
git pull origin firstname_lastname/feature/some-feature
cd ..
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway to feature branch for QA"
```

### Clean Test Environment

```bash
# Reset all submodules to clean state
git submodule foreach 'git clean -fd && git reset --hard HEAD'
git submodule update --init --recursive
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `./team_submodule_commands/qa-team/pull_submodules.sh` | Pull all submodules |
| `git submodule update --init --recursive` | Initialize all submodules |
| `git submodule update --remote --recursive` | Update all submodules |
| `git submodule status` | Check all submodule statuses |
| `git submodule foreach 'git status'` | Check status of each submodule |
| `git submodule foreach 'git pull'` | Pull latest in all submodules |

## 🧪 Testing Workflow

### Full Integration Test Setup

```bash
# 1. Update all submodules
git submodule update --remote --recursive

# 2. Install dependencies for each service
cd platform-services/backend/deepiri-api-gateway && npm install && cd ..
cd deepiri-web-frontend && npm install && cd ..
cd diri-cyrex && pip install -r requirements.txt && cd ..

# 3. Run tests
cd platform-services/backend/deepiri-api-gateway && npm test && cd ..
cd deepiri-web-frontend && npm test && cd ..
cd diri-cyrex && pytest && cd ..
```

### Quick Test Check

```bash
# Check if all submodules are up to date
git submodule status | grep -v "^ "

# If any show modified, sync them
git submodule update --remote
```

## 🔗 Related Documentation

- [Main Submodule Guide](../SUBMODULE_COMMANDS.md)
- [README](../README.md)
- [Backend Team Guide](../backend-team/BACKEND_TEAM.md)
- [Frontend Team Guide](../frontend-team/FRONTEND_TEAM.md)
- [AI Team Guide](../ai-team/AI_TEAM.md)

---

**Team**: QA Team  
**Required Submodules**: **ALL** (for comprehensive testing)  
**Repositories**: All team repositories  
**Pull Script**: `./team_submodule_commands/qa-team/pull_submodules.sh`

