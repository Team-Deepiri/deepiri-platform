# Guide: Converting Helox, ModelKit, and Synapse to Git Submodules

This guide explains how to convert `diri-helox`, `deepiri-modelkit`, and `deepiri-synapse` into Git submodules and integrate them into the existing submodule management system.

## Prerequisites

1. **Create the repositories** on GitHub (or your Git hosting):
   - `Team-Deepiri/diri-helox.git`
   - `Team-Deepiri/deepiri-modelkit.git`
   - `Team-Deepiri/deepiri-synapse.git`

2. **Initialize and push** the code to these repositories:
   ```bash
   # For each repository (helox, modelkit, synapse):
   cd diri-helox  # or deepiri-modelkit, or deepiri-synapse
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin git@github.com:Team-Deepiri/diri-helox.git
   git branch -M main
   git push -u origin main
   ```

## Step 1: Add to `.gitmodules`

Edit `deepiri/.gitmodules` and add the three new submodules:

```ini
[submodule "deepiri-core-api"]
	path = deepiri-core-api
	url = git@github.com:Team-Deepiri/deepiri-core-api.git
[submodule "diri-cyrex"]
	path = diri-cyrex
	url = git@github.com:Team-Deepiri/diri-cyrex.git
[submodule "platform-services/backend/deepiri-api-gateway"]
	path = platform-services/backend/deepiri-api-gateway
	url = git@github.com:Team-Deepiri/deepiri-api-gateway.git
[submodule "deepiri-web-frontend"]
	path = deepiri-web-frontend
	url = git@github.com:Team-Deepiri/deepiri-web-frontend.git
[submodule "platform-services/backend/deepiri-external-bridge-service"]
	path = platform-services/backend/deepiri-external-bridge-service
	url = git@github.com:Team-Deepiri/deepiri-external-bridge-service.git
[submodule "platform-services/backend/deepiri-auth-service"]
	path = platform-services/backend/deepiri-auth-service
	url = git@github.com:Team-Deepiri/deepiri-auth-service.git

# NEW SUBMODULES
[submodule "diri-helox"]
	path = diri-helox
	url = git@github.com:Team-Deepiri/diri-helox.git
[submodule "deepiri-modelkit"]
	path = deepiri-modelkit
	url = git@github.com:Team-Deepiri/deepiri-modelkit.git
[submodule "platform-services/shared/deepiri-synapse"]
	path = platform-services/shared/deepiri-synapse
	url = git@github.com:Team-Deepiri/deepiri-synapse.git
```

## Step 2: Remove Existing Directories and Add as Submodules

**⚠️ IMPORTANT**: Backup your work first! These commands will remove the existing directories.

```bash
cd deepiri

# Remove existing directories (they will be replaced by submodules)
rm -rf diri-helox
rm -rf deepiri-modelkit
rm -rf platform-services/shared/deepiri-synapse

# Add as submodules
git submodule add git@github.com:Team-Deepiri/diri-helox.git diri-helox
git submodule add git@github.com:Team-Deepiri/deepiri-modelkit.git deepiri-modelkit
git submodule add git@github.com:Team-Deepiri/deepiri-synapse.git platform-services/shared/deepiri-synapse

# Commit the changes
git add .gitmodules
git commit -m "Add diri-helox, deepiri-modelkit, and deepiri-synapse as submodules"
```

## Step 3: Update Git Hooks

The git hooks (`post-checkout` and `post-merge`) automatically sync hooks to submodules. They should work automatically, but verify they include the new submodules.

### Check `.git-hooks/post-checkout` and `.git-hooks/post-merge`

These hooks should already handle all submodules dynamically. Verify the `sync_hooks_to_submodule` function works for the new paths:

```bash
# The hooks should automatically detect:
# - diri-helox
# - deepiri-modelkit
# - platform-services/shared/deepiri-synapse
```

If needed, the hooks use `git submodule foreach` which will include all submodules automatically.

## Step 4: Update Team Submodule Commands

### 4.1 Update `pull_submodules.sh` for Each Team

For each team in `team_submodule_commands/*/pull_submodules.sh`, add the new submodules to the appropriate team's list.

#### AI Team (`team_submodule_commands/ai-team/pull_submodules.sh`)

Add `deepiri-modelkit` and `platform-services/shared/deepiri-synapse`:

```bash
# AI Team required submodules
declare -a SUBMODULES=(
    "diri-cyrex"
    "platform-services/backend/deepiri-external-bridge-service"
    "deepiri-modelkit"                    # NEW
    "platform-services/shared/deepiri-synapse"  # NEW
)
```

#### ML Team (`team_submodule_commands/ml-team/pull_submodules.sh`)

Add `diri-helox`, `deepiri-modelkit`, and `platform-services/shared/deepiri-synapse`:

```bash
# ML Team required submodules
declare -a SUBMODULES=(
    "diri-cyrex"
    "diri-helox"                          # NEW
    "deepiri-modelkit"                    # NEW
    "platform-services/shared/deepiri-synapse"  # NEW
)
```

#### Backend Team (`team_submodule_commands/backend-team/pull_submodules.sh`)

Add `deepiri-modelkit` and `platform-services/shared/deepiri-synapse`:

```bash
# Backend Team required submodules
declare -a SUBMODULES=(
    "deepiri-core-api"
    "platform-services/backend/deepiri-api-gateway"
    "platform-services/backend/deepiri-auth-service"
    "platform-services/backend/deepiri-external-bridge-service"
    "deepiri-web-frontend"
    "deepiri-modelkit"                    # NEW
    "platform-services/shared/deepiri-synapse"  # NEW
)
```

#### Infrastructure Team (`team_submodule_commands/infrastructure-team/pull_submodules.sh`)

Add all three new submodules:

```bash
# Infrastructure Team required submodules
declare -a SUBMODULES=(
    "deepiri-core-api"
    "diri-cyrex"
    "diri-helox"                          # NEW
    "platform-services/backend/deepiri-api-gateway"
    "platform-services/backend/deepiri-auth-service"
    "platform-services/backend/deepiri-external-bridge-service"
    "deepiri-modelkit"                    # NEW
    "platform-services/shared/deepiri-synapse"  # NEW
)
```

#### QA Team (`team_submodule_commands/qa-team/pull_submodules.sh`)

Add `deepiri-modelkit` and `platform-services/shared/deepiri-synapse`:

```bash
# QA Team required submodules
declare -a SUBMODULES=(
    "platform-services/backend/deepiri-auth-service"
    "platform-services/backend/deepiri-external-bridge-service"
    "platform-services/backend/deepiri-api-gateway"
    "deepiri-core-api"
    "deepiri-web-frontend"
    "deepiri-modelkit"                    # NEW
    "platform-services/shared/deepiri-synapse"  # NEW
)
```

#### Frontend Team (`team_submodule_commands/frontend-team/pull_submodules.sh`)

Add `deepiri-modelkit` (if needed for frontend):

```bash
# Frontend Team required submodules
declare -a SUBMODULES=(
    "deepiri-web-frontend"
    "platform-services/backend/deepiri-auth-service"
    "platform-services/backend/deepiri-api-gateway"
    "deepiri-modelkit"                    # NEW (if frontend needs contracts)
)
```

#### Platform Engineers (`team_submodule_commands/platform-engineers/pull_submodules.sh`)

Add all three (they pull all submodules anyway, but for clarity):

```bash
# Platform Engineers pull ALL submodules
# The script should already handle all submodules, but for reference:
# - diri-helox
# - deepiri-modelkit
# - platform-services/shared/deepiri-synapse
```

### 4.2 Update `update_submodules.sh` for Each Team

Update the `SUBMODULES` array in each team's `update_submodules.sh` file with the same additions as above.

#### Example: AI Team `update_submodules.sh`

```bash
# AI Team required submodules
declare -a SUBMODULES=(
    "diri-cyrex"
    "platform-services/backend/deepiri-external-bridge-service"
    "deepiri-modelkit"                    # NEW
    "platform-services/shared/deepiri-synapse"  # NEW
)
```

Apply the same pattern to all other teams' `update_submodules.sh` files.

## Step 5: Verify Submodule Setup

After adding the submodules, verify everything works:

```bash
cd deepiri

# Initialize and update all submodules
git submodule update --init --recursive

# Verify submodules are tracked
git submodule status

# Check that new submodules appear
git submodule status | grep -E "(helox|modelkit|synapse)"
```

## Step 6: Update Dependencies

### Update `diri-cyrex/requirements.txt`

The modelkit dependency should reference the submodule:

```txt
# Deepiri ModelKit (shared contracts and utilities)
-e ../deepiri-modelkit
```

### Update `diri-helox/requirements.txt`

```txt
# Shared dependencies
-e ../deepiri-modelkit  # Install from local source
```

### Update `platform-services/shared/deepiri-synapse/requirements.txt`

```txt
# Deepiri ModelKit (for event schemas)
-e ../../../deepiri-modelkit
```

## Step 7: Update Docker Compose Build Contexts

Verify that Docker Compose build contexts still work with submodules:

- `diri-helox/Dockerfile.jupyter` - should work as-is
- `platform-services/shared/deepiri-synapse/Dockerfile` - should work as-is
- ModelKit doesn't need a Dockerfile (it's a Python package)

## Step 8: Team-Specific Submodule Mapping

### Summary of Which Teams Need Which Submodules

| Team | diri-helox | deepiri-modelkit | deepiri-synapse |
|------|------------|------------------|-----------------|
| **AI Team** | ❌ | ✅ | ✅ |
| **ML Team** | ✅ | ✅ | ✅ |
| **Backend Team** | ❌ | ✅ | ✅ |
| **Infrastructure Team** | ✅ | ✅ | ✅ |
| **QA Team** | ❌ | ✅ | ✅ |
| **Frontend Team** | ❌ | ⚠️ (optional) | ❌ |
| **Platform Engineers** | ✅ | ✅ | ✅ |

## Step 9: Testing the Setup

1. **Clone fresh repository**:
   ```bash
   git clone --recursive git@github.com:Team-Deepiri/Deepiri.git
   cd Deepiri
   ```

2. **Or update existing**:
   ```bash
   cd deepiri
   git pull
   git submodule update --init --recursive
   ```

3. **Test team scripts**:
   ```bash
   # Test AI team
   ./team_submodule_commands/ai-team/pull_submodules.sh
   ./team_submodule_commands/ai-team/update_submodules.sh
   
   # Test ML team
   ./team_submodule_commands/ml-team/pull_submodules.sh
   ./team_submodule_commands/ml-team/update_submodules.sh
   ```

## Step 10: Commit and Push

After all changes:

```bash
cd deepiri

# Stage all changes
git add .gitmodules
git add team_submodule_commands/

# Commit
git commit -m "Add diri-helox, deepiri-modelkit, and deepiri-synapse as submodules

- Added three new submodules to .gitmodules
- Updated all team pull_submodules.sh scripts
- Updated all team update_submodules.sh scripts
- Teams can now manage these submodules independently"

# Push
git push origin main
```

## Troubleshooting

### Issue: Submodule shows as "dirty" or "modified"

```bash
# Check status
git submodule status

# If a submodule shows as modified, you may have uncommitted changes
cd diri-helox  # or the problematic submodule
git status
git add .
git commit -m "Update"
cd ..
git add diri-helox
git commit -m "Update submodule reference"
```

### Issue: Submodule path doesn't exist after clone

```bash
# Initialize all submodules
git submodule update --init --recursive

# Or use team-specific script
./team_submodule_commands/ai-team/pull_submodules.sh
```

### Issue: Build fails because modelkit not found

Ensure the submodule is initialized and the path is correct:

```bash
# Verify modelkit exists
ls -la deepiri-modelkit/

# Reinstall dependencies
cd diri-cyrex
pip install -e ../deepiri-modelkit
```

## Quick Reference: Submodule Commands

```bash
# Initialize all submodules
git submodule update --init --recursive

# Update all submodules to latest
git submodule update --remote --recursive

# Update specific submodule
git submodule update --remote diri-helox

# Enter submodule and work on it
cd diri-helox
git checkout main
git pull origin main
# Make changes, commit, push
cd ..

# Update parent repo to point to new submodule commit
git add diri-helox
git commit -m "Update diri-helox submodule"
```

## Notes

- **ModelKit** is a shared library used by Cyrex, Helox, and Synapse
- **Helox** is primarily for ML team, but infrastructure team may need it
- **Synapse** is used by all teams that need event streaming (AI, ML, Backend, Infrastructure, QA)
- All three should be initialized when setting up the development environment

