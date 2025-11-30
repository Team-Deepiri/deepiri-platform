# Infrastructure Team - Submodule Commands

## 🎯 Required Submodules

The Infrastructure Team needs access to:
- **deepiri-api-gateway** - API Gateway service
- **deepiri-external-bridge-service** - External integrations bridge

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri-platform

# Set up Git hooks (REQUIRED - protects main and dev branches)
./setup-hooks.sh

# Pull latest changes
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/infrastructure-team/pull_submodules.sh

# OR manually initialize and update infrastructure submodules
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/infrastructure-team/pull_submodules.sh

# OR manually update infrastructure submodules to latest
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
```

## 🔧 Working with Infrastructure Submodules

### Make Changes to API Gateway

**⚠️ IMPORTANT: Use the branch naming convention: `firstname_lastname/feature/feature_name` or `firstname_lastname/bug/bug_fix_name`**

```bash
# Navigate to API Gateway submodule
cd platform-services/backend/deepiri-api-gateway

# Create feature branch with your name
# Example: john_doe/feature/add-rate-limiting
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes (routing, middleware, etc.)
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: add new route / improve gateway performance"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the deepiri-api-gateway repository
# After PR is merged, return to main repo
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
# Navigate to any infrastructure submodule
cd platform-services/backend/deepiri-api-gateway  # or external-bridge-service

# Create bug fix branch with your name
# Example: jane_smith/bug/fix-gateway-timeout
git checkout -b firstname_lastname/bug/bug_fix_name

# Make your fixes
# ... edit files ...

# Commit changes
git add .
git commit -m "fix: description of bug fix"

# Push bug fix branch
git push origin firstname_lastname/bug/bug_fix_name

# Create PR in the respective repository
cd ../../..
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

## 🌿 Branch Naming Convention

**Required Format:**
- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/add-rate-limiting`
- `jane_smith/feature/improve-gateway-performance`
- `bob_jones/bug/fix-gateway-timeout`
- `alice_williams/bug/fix-webhook-handling`

**Why?**
- Easy to identify who owns the branch
- Clear separation between features and bug fixes
- Better code review organization

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
git checkout -b firstname_lastname/feature/new-routing
# ... make changes ...
git add .
git commit -m "feat: new routing feature"
git push origin firstname_lastname/feature/new-routing
cd ../../..

# Update main repo
git add platform-services/backend/deepiri-api-gateway
git commit -m "chore: update api-gateway to feature branch"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `./team_submodule_commands/infrastructure-team/pull_submodules.sh` | Pull all infrastructure submodules |
| `git submodule update --init platform-services/backend/deepiri-api-gateway` | Initialize API Gateway |
| `git submodule update --init platform-services/backend/deepiri-external-bridge-service` | Initialize External Bridge |
| `git submodule update --remote platform-services/backend/deepiri-api-gateway` | Update API Gateway |
| `git submodule status` | Check all submodule statuses |
| `git checkout -b firstname_lastname/feature/name` | Create feature branch |

## 🔗 Related Documentation

- [Main Submodule Guide](../SUBMODULE_COMMANDS.md)
- [README](../README.md)
- [Platform Engineers Guide](../platform-engineers/PLATFORM_ENGINEERS.md) - Similar workflow

---

**Team**: Infrastructure Team  
**Primary Submodules**: 
- `platform-services/backend/deepiri-api-gateway`
- `platform-services/backend/deepiri-external-bridge-service`  
**Repositories**: 
- `git@github.com:Team-Deepiri/deepiri-api-gateway.git`
- `git@github.com:Team-Deepiri/deepiri-external-bridge-service.git`  
**Pull Script**: `./team_submodule_commands/infrastructure-team/pull_submodules.sh`

