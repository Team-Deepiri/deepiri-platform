# Backend Team - Submodule Commands

## 🎯 Required Submodules

The Backend Team has **direct access** to these repositories:
- **Team-Deepiri/deepiri-api-gateway** - Main backend API gateway
- **Team-Deepiri/deepiri-auth-service** - Authentication service
- **Team-Deepiri/deepiri-external-bridge-service** - External integrations bridge
- **Team-Deepiri/deepiri-web-frontend** - Frontend application (for API integration testing)

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
./team_submodule_commands/backend-team/pull_submodules.sh

# OR manually initialize and update all backend submodules
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
git submodule update --init --recursive platform-services/backend/deepiri-auth-service
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
git submodule update --init --recursive deepiri-web-frontend
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/backend-team/pull_submodules.sh

# OR manually update all backend submodules to latest
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
git submodule update --remote deepiri-web-frontend
```

## 🔧 Working with Backend Submodules

### Make Changes to API Gateway

**⚠️ IMPORTANT: Use the branch naming convention: `firstname_lastname/feature/feature_name` or `firstname_lastname/bug/bug_fix_name`**

```bash
# Navigate to API Gateway submodule
cd platform-services/backend/deepiri-api-gateway

# Create feature branch with your name
# Example: john_doe/feature/add-user-endpoint
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes
# ... edit files in src/ ...

# Commit changes
git add .
git commit -m "feat: add new endpoint / improve performance"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the platform-services/backend/deepiri-api-gateway repository
# After PR is merged, return to main repo
cd ..

# Update main repo
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway submodule"
git push origin main
```

### Make Changes to Auth Service

```bash
# Navigate to Auth Service submodule
cd platform-services/backend/deepiri-auth-service

# Create feature branch with your name
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes (auth logic, JWT, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: improve authentication flow"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the deepiri-auth-service repository
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

# Create feature branch with your name
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes (routing, middleware, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: add new route / improve gateway"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the deepiri-api-gateway repository
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

# Create feature branch with your name
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes (integrations, webhooks, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: add new external integration"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the deepiri-external-bridge-service repository
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-external-bridge-service
git commit -m "chore: update external-bridge submodule"
git push origin main
```

### Working on Bug Fixes

```bash
# Navigate to any backend submodule
cd platform-services/backend/deepiri-api-gateway  # or any other backend service

# Create bug fix branch with your name
# Example: jane_smith/bug/fix-api-timeout
git checkout -b firstname_lastname/bug/bug_fix_name

# Make your fixes
# ... edit files ...

# Commit changes
git add .
git commit -m "fix: description of bug fix"

# Push bug fix branch
git push origin firstname_lastname/bug/bug_fix_name

# Create PR in the respective repository
cd ..
```

### Update All Backend Submodules

```bash
# From main repo root - update all at once
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
git submodule update --remote deepiri-web-frontend

# Commit all updates
git add platform-services/backend/deepiri-api-gateway
git add platform-services/backend/deepiri-auth-service
git add platform-services/backend/deepiri-external-bridge-service
git add deepiri-web-frontend
git commit -m "chore: update all backend submodules"
git push origin main
```

### Check Submodule Status

```bash
# Check all submodules
git submodule status

# Check specific backend submodules
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status platform-services/backend/deepiri-auth-service
git submodule status platform-services/backend/deepiri-external-bridge-service
git submodule status deepiri-web-frontend
```

## 🌿 Branch Naming Convention

**Required Format:**
- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/add-user-authentication`
- `jane_smith/feature/improve-api-performance`
- `bob_jones/bug/fix-database-connection-pool`
- `alice_williams/bug/fix-jwt-expiration`

**Why?**
- Easy to identify who owns the branch
- Clear separation between features and bug fixes
- Better code review organization

## 🐛 Troubleshooting

### Submodule Not Initialized

```bash
# Initialize all backend submodules
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
git submodule update --init --recursive platform-services/backend/deepiri-auth-service
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
git submodule update --init --recursive deepiri-web-frontend
```

### Submodule Out of Sync

```bash
# Sync a specific submodule
cd platform-services/backend/deepiri-api-gateway
git checkout main
git pull origin main
cd ..
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: sync api-gateway submodule"
```

### Working on Feature Branch

```bash
# Create feature branch in submodule
cd platform-services/backend/deepiri-api-gateway
git checkout -b firstname_lastname/feature/new-endpoint
# ... make changes ...
git add .
git commit -m "feat: new endpoint"
git push origin firstname_lastname/feature/new-endpoint
cd ..

# Update main repo
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway to feature branch"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `./team_submodule_commands/backend-team/pull_submodules.sh` | Pull all backend submodules |
| `git submodule update --init --recursive platform-services/backend/deepiri-api-gateway` | Initialize API Gateway |
| `git submodule update --remote platform-services/backend/deepiri-api-gateway` | Update API Gateway |
| `git submodule status` | Check all submodule statuses |
| `git submodule update --remote` | Update all submodules |
| `git checkout -b firstname_lastname/feature/name` | Create feature branch |

## 🔗 Related Documentation

- [Main Submodule Guide](../SUBMODULE_COMMANDS.md)
- [README](../README.md)
- [Infrastructure Team Guide](../infrastructure-team/INFRASTRUCTURE_TEAM.md) - Similar workflow

---

**Team**: Backend Team  
**Primary Submodules**: 
- `platform-services/backend/deepiri-api-gateway`
- `platform-services/backend/deepiri-auth-service`
- `platform-services/backend/deepiri-external-bridge-service`
- `deepiri-web-frontend`  
**Repositories**: 
- `git@github.com:Team-Deepiri/deepiri-api-gateway.git`
- `git@github.com:Team-Deepiri/deepiri-auth-service.git`
- `git@github.com:Team-Deepiri/deepiri-external-bridge-service.git`  
**Pull Script**: `./team_submodule_commands/backend-team/pull_submodules.sh`

