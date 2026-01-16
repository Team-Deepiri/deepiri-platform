# Quick Command Workflow: Initialize Submodules

## Current Status
- ✅ Directories exist: `diri-helox`, `deepiri-modelkit`, `platform-services/shared/deepiri-synapse`
- ✅ Already in `.gitmodules`
- ⚠️ Need to: Initialize as separate repos → Push to GitHub → Re-add as submodules

## Option 1: Use the Script (Recommended)

### Bash/Git Bash:
```bash
cd deepiri
chmod +x scripts/initialize-new-submodules.sh
./scripts/initialize-new-submodules.sh
```

### PowerShell:
```powershell
cd deepiri
.\scripts\initialize-new-submodules.ps1
```

## Option 2: Manual Commands

### Step 1: Save All Progress
```bash
cd deepiri
git add -A
git commit -m "Save progress: configmaps, docker-compose updates, submodule scripts"
```

### Step 2: Initialize & Push Each Repo

#### diri-helox:
```bash
cd diri-helox
git init
git add -A
git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:Team-Deepiri/diri-helox.git
git push -u origin main
cd ..
```

#### deepiri-modelkit:
```bash
cd deepiri-modelkit
git init
git add -A
git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:Team-Deepiri/deepiri-modelkit.git
git push -u origin main
cd ..
```

#### deepiri-synapse:
```bash
cd platform-services/shared/deepiri-synapse
git init
git add -A
git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:Team-Deepiri/deepiri-synapse.git
git push -u origin main
cd ../../..
```

### Step 3: Remove & Re-add as Submodules
```bash
cd deepiri

# Remove existing directories
rm -rf diri-helox
rm -rf deepiri-modelkit
rm -rf platform-services/shared/deepiri-synapse

# Add as submodules (will pull from GitHub)
git submodule add git@github.com:Team-Deepiri/diri-helox.git diri-helox
git submodule add git@github.com:Team-Deepiri/deepiri-modelkit.git deepiri-modelkit
git submodule add git@github.com:Team-Deepiri/deepiri-synapse.git platform-services/shared/deepiri-synapse
```

### Step 4: Commit Submodule References
```bash
git add .gitmodules
git commit -m "Add diri-helox, deepiri-modelkit, and deepiri-synapse as submodules"
```

### Step 5: Verify & Push
```bash
git submodule status
git push
git push --recurse-submodules=on-demand
```

## One-Liner (Bash - After Creating GitHub Repos)

```bash
cd deepiri && \
git add -A && git commit -m "Save progress before submodule init" && \
(cd diri-helox && git init && git add -A && git commit -m "Initial commit" && git branch -M main && git remote add origin git@github.com:Team-Deepiri/diri-helox.git && git push -u origin main) && \
(cd deepiri-modelkit && git init && git add -A && git commit -m "Initial commit" && git branch -M main && git remote add origin git@github.com:Team-Deepiri/deepiri-modelkit.git && git push -u origin main) && \
(cd platform-services/shared/deepiri-synapse && git init && git add -A && git commit -m "Initial commit" && git branch -M main && git remote add origin git@github.com:Team-Deepiri/deepiri-synapse.git && git push -u origin main) && \
cd .. && rm -rf diri-helox deepiri-modelkit platform-services/shared/deepiri-synapse && \
git submodule add git@github.com:Team-Deepiri/diri-helox.git diri-helox && \
git submodule add git@github.com:Team-Deepiri/deepiri-modelkit.git deepiri-modelkit && \
git submodule add git@github.com:Team-Deepiri/deepiri-synapse.git platform-services/shared/deepiri-synapse && \
git add .gitmodules && git commit -m "Add diri-helox, deepiri-modelkit, and deepiri-synapse as submodules" && \
git submodule status && echo "✓ Done! Run 'git push' to push submodule references."
```

## Important Notes

1. **Create GitHub repos first** (if they don't exist):
   - https://github.com/Team-Deepiri/diri-helox
   - https://github.com/Team-Deepiri/deepiri-modelkit
   - https://github.com/Team-Deepiri/deepiri-synapse

2. **If repos already exist on GitHub**, the `git push` commands will work. If not, create them first.

3. **If submodules are already in .gitmodules** but directories are empty:
   ```bash
   git submodule update --init --recursive
   ```

4. **Verify after completion**:
   ```bash
   git submodule status
   ```

