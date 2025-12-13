# Complete Workflow: Initialize Helox, ModelKit, and Synapse as Submodules

This document provides the exact command workflow to save all progress, initialize the three new repositories, and link them as submodules.

## Prerequisites

1. **Create the repositories on GitHub** (if they don't exist):
   - `Team-Deepiri/diri-helox`
   - `Team-Deepiri/deepiri-modelkit`
   - `Team-Deepiri/deepiri-synapse`

2. **Ensure you have SSH access** to GitHub (or update URLs to HTTPS if needed)

## Quick Start: Use the Script

### For Linux/Mac/Git Bash:
```bash
cd deepiri
chmod +x scripts/initialize-new-submodules.sh
./scripts/initialize-new-submodules.sh
```

### For Windows PowerShell:
```powershell
cd deepiri
.\scripts\initialize-new-submodules.ps1
```

## Manual Workflow (Step-by-Step)

If you prefer to run commands manually, follow these steps:

### Step 1: Save All Current Progress

```bash
cd deepiri

# Check current status
git status

# Stage all changes
git add -A

# Commit with descriptive message
git commit -m "Save progress before initializing new submodules (helox, modelkit, synapse)"

# Optional: Push to remote
git push
```

### Step 2: Initialize Each Repository as Separate Git Repo

For each repository (`diri-helox`, `deepiri-modelkit`, `platform-services/shared/deepiri-synapse`):

#### For diri-helox:
```bash
cd diri-helox

# Initialize if not already a git repo
if [ ! -d ".git" ]; then
    git init
    git add -A
    git commit -m "Initial commit"
    git branch -M main
fi

# Add remote (update URL if needed)
git remote add origin git@github.com:Team-Deepiri/diri-helox.git
# OR if remote exists, update it:
# git remote set-url origin git@github.com:Team-Deepiri/diri-helox.git

# Push to remote (create repo on GitHub first if it doesn't exist)
git push -u origin main

cd ..
```

#### For deepiri-modelkit:
```bash
cd deepiri-modelkit

# Initialize if not already a git repo
if [ ! -d ".git" ]; then
    git init
    git add -A
    git commit -m "Initial commit"
    git branch -M main
fi

# Add remote
git remote add origin git@github.com:Team-Deepiri/deepiri-modelkit.git
# OR update existing:
# git remote set-url origin git@github.com:Team-Deepiri/deepiri-modelkit.git

# Push to remote
git push -u origin main

cd ..
```

#### For deepiri-synapse:
```bash
cd platform-services/shared/deepiri-synapse

# Initialize if not already a git repo
if [ ! -d ".git" ]; then
    git init
    git add -A
    git commit -m "Initial commit"
    git branch -M main
fi

# Add remote
git remote add origin git@github.com:Team-Deepiri/deepiri-synapse.git
# OR update existing:
# git remote set-url origin git@github.com:Team-Deepiri/deepiri-synapse.git

# Push to remote
git push -u origin main

cd ../../..
```

### Step 3: Remove Existing Directories and Add as Submodules

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
```

**Note**: If the directories are already listed in `.gitmodules` but not initialized, you can skip the `git submodule add` commands and just run:
```bash
git submodule update --init --recursive
```

### Step 4: Commit Submodule References

```bash
cd deepiri

# Stage .gitmodules and submodule entries
git add .gitmodules
git add diri-helox
git add deepiri-modelkit
git add platform-services/shared/deepiri-synapse

# Commit
git commit -m "Add diri-helox, deepiri-modelkit, and deepiri-synapse as submodules"
```

### Step 5: Verify and Push

```bash
# Verify submodule setup
git submodule status

# Initialize all submodules (if not already done)
git submodule update --init --recursive

# Push to remote
git push

# Push submodule references
git push --recurse-submodules=on-demand
```

## Complete One-Liner Workflow (Bash)

If you want to run everything at once (after creating GitHub repos):

```bash
cd deepiri && \
git add -A && \
git commit -m "Save progress before initializing new submodules" && \
cd diri-helox && git init && git add -A && git commit -m "Initial commit" && git branch -M main && git remote add origin git@github.com:Team-Deepiri/diri-helox.git && git push -u origin main && cd .. && \
cd deepiri-modelkit && git init && git add -A && git commit -m "Initial commit" && git branch -M main && git remote add origin git@github.com:Team-Deepiri/deepiri-modelkit.git && git push -u origin main && cd .. && \
cd platform-services/shared/deepiri-synapse && git init && git add -A && git commit -m "Initial commit" && git branch -M main && git remote add origin git@github.com:Team-Deepiri/deepiri-synapse.git && git push -u origin main && cd ../../.. && \
rm -rf diri-helox deepiri-modelkit platform-services/shared/deepiri-synapse && \
git submodule add git@github.com:Team-Deepiri/diri-helox.git diri-helox && \
git submodule add git@github.com:Team-Deepiri/deepiri-modelkit.git deepiri-modelkit && \
git submodule add git@github.com:Team-Deepiri/deepiri-synapse.git platform-services/shared/deepiri-synapse && \
git add .gitmodules && git commit -m "Add diri-helox, deepiri-modelkit, and deepiri-synapse as submodules" && \
git submodule status && \
echo "✓ Workflow complete! Run 'git push' to push submodule references."
```

## Troubleshooting

### If repositories already exist in .gitmodules:
If the submodules are already listed in `.gitmodules` but the directories don't exist:
```bash
git submodule update --init --recursive
```

### If you need to update submodule URLs:
```bash
git config -f .gitmodules submodule.diri-helox.url git@github.com:Team-Deepiri/diri-helox.git
git submodule sync
```

### If submodule directories are empty:
```bash
git submodule update --init --recursive
```

### If you need to remove and re-add a submodule:
```bash
# Remove from .gitmodules and .git/config
git submodule deinit -f diri-helox
git rm -f diri-helox
rm -rf .git/modules/diri-helox

# Re-add
git submodule add git@github.com:Team-Deepiri/diri-helox.git diri-helox
```

## Verification Checklist

After completing the workflow, verify:

- [ ] All three repositories exist on GitHub
- [ ] `.gitmodules` contains entries for all three submodules
- [ ] `git submodule status` shows all three submodules
- [ ] Submodule directories exist and contain files
- [ ] `git push` successfully pushes submodule references
- [ ] Team submodule scripts (`pull_submodules.sh`, `update_submodules.sh`) work correctly

## Next Steps

After initializing submodules:

1. **Update team scripts** (already done):
   - `team_submodule_commands/*/pull_submodules.sh`
   - `team_submodule_commands/*/update_submodules.sh`

2. **Verify git hooks** sync to new submodules (should be automatic)

3. **Test submodule operations**:
   ```bash
   git submodule update --remote
   git submodule foreach git pull origin main
   ```

