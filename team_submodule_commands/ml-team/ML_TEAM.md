# ML Team - Submodule Commands

## 🎯 Required Submodules

The ML Team needs access to:
- **diri-cyrex** - AI/ML service (Cyrex) - Contains ML models, training scripts, and MLOps

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
./team_submodule_commands/ml-team/pull_submodules.sh

# OR manually initialize and update ML submodule
git submodule update --init --recursive diri-cyrex
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/ml-team/pull_submodules.sh

# OR manually update ML submodule to latest
git submodule update --remote diri-cyrex
```

## 🔧 Working with ML Submodule

### Make Changes to ML Code

**⚠️ IMPORTANT: Use the branch naming convention: `firstname_lastname/feature/feature_name` or `firstname_lastname/bug/bug_fix_name`**

```bash
# Navigate to ML submodule
cd diri-cyrex

# Create feature branch with your name
# Example: john_doe/feature/improve-model-accuracy
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes (models, training scripts, etc.)
# ... edit files in app/train/, app/ml_models/, etc. ...

# Commit changes
git add .
git commit -m "feat: improve model accuracy / add new model"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the diri-cyrex repository
# After PR is merged, return to main repo
cd ..

# Update main repo to reference new submodule commit
git add diri-cyrex
git commit -m "chore: update diri-cyrex submodule"
git push origin main
```

### Working with Training Scripts

```bash
# Navigate to training directory
cd diri-cyrex/app/train

# Create feature branch for training work
cd ../..
git checkout -b firstname_lastname/feature/train-new-model

# Run training scripts
cd app/train
python scripts/train_model.py

# Commit trained models/configs
cd ../..
git add app/train/
git commit -m "feat: update model weights"
git push origin firstname_lastname/feature/train-new-model
cd ..
```

### Working on Bug Fixes

```bash
# Navigate to ML submodule
cd diri-cyrex

# Create bug fix branch with your name
# Example: jane_smith/bug/fix-training-memory-leak
git checkout -b firstname_lastname/bug/bug_fix_name

# Make your fixes
# ... edit files ...

# Commit changes
git add .
git commit -m "fix: description of bug fix"

# Push bug fix branch
git push origin firstname_lastname/bug/bug_fix_name

# Create PR in the diri-cyrex repository
cd ..
```

### Update to Latest ML Code

```bash
# From main repo root
git submodule update --remote diri-cyrex

# Review changes
cd diri-cyrex
git log --oneline -10
cd ..

# Commit submodule update
git add diri-cyrex
git commit -m "chore: update diri-cyrex to latest"
git push origin main
```

### Check Submodule Status

```bash
# Check all submodules
git submodule status

# Check only ML submodule
git submodule status diri-cyrex
```

## 🌿 Branch Naming Convention

**Required Format:**
- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/improve-classifier-accuracy`
- `jane_smith/feature/add-new-training-pipeline`
- `bob_jones/bug/fix-memory-leak-in-training`
- `alice_williams/bug/fix-model-loading-error`

**Why?**
- Easy to identify who owns the branch
- Clear separation between features and bug fixes
- Better code review organization

## 🐛 Troubleshooting

### Submodule Not Initialized

```bash
# If you see empty directory
git submodule update --init diri-cyrex
```

### Submodule Out of Sync

```bash
# If submodule shows as modified but you haven't changed anything
cd diri-cyrex
git checkout main
git pull origin main
cd ..
git add diri-cyrex
git commit -m "chore: sync diri-cyrex submodule"
```

### Working on Model Training Branch

```bash
# Create training branch in submodule
cd diri-cyrex
git checkout -b firstname_lastname/feature/train-new-model
# ... train model, update weights ...
git add .
git commit -m "feat: add new trained model"
git push origin firstname_lastname/feature/train-new-model
cd ..

# Update main repo
git add diri-cyrex
git commit -m "chore: update diri-cyrex with new model"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `./team_submodule_commands/ml-team/pull_submodules.sh` | Pull all ML submodules |
| `git submodule update --init diri-cyrex` | Initialize ML submodule |
| `git submodule update --remote diri-cyrex` | Update to latest ML code |
| `git submodule status diri-cyrex` | Check ML submodule status |
| `cd diri-cyrex && git pull` | Pull latest in submodule |
| `cd diri-cyrex/app/train && ls` | View training scripts |
| `git checkout -b firstname_lastname/feature/name` | Create feature branch |

## 🔗 Related Documentation

- [Main Submodule Guide](../SUBMODULE_COMMANDS.md)
- [README](../README.md)
- [AI Team Guide](../ai-team/AI_TEAM.md) - Similar workflow

---

**Team**: ML Team  
**Primary Submodule**: `diri-cyrex`  
**Repository**: `git@github.com:Team-Deepiri/diri-cyrex.git`  
**Key Directories**: `app/train/`, `app/ml_models/`, `mlops/`  
**Pull Script**: `./team_submodule_commands/ml-team/pull_submodules.sh`

