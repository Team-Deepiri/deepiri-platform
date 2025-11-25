# ML Team - Submodule Commands

## 🎯 Required Submodules

The ML Team needs access to:
- **diri-cyrex** - AI/ML service (Cyrex) - Contains ML models, training scripts, and MLOps

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri

# Pull latest changes
git pull origin main

# Initialize and update ML submodule
git submodule update --init --recursive diri-cyrex
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Update ML submodule to latest
git submodule update --remote diri-cyrex
```

## 🔧 Working with ML Submodule

### Make Changes to ML Code

```bash
# Navigate to ML submodule
cd diri-cyrex

# Check current branch
git status

# Make your changes (models, training scripts, etc.)
# ... edit files in app/train/, app/ml_models/, etc. ...

# Commit changes
git add .
git commit -m "feat: improve model accuracy / add new model"

# Push to ML repository
git push origin main

# Return to main repo
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

# Run training scripts
python scripts/train_model.py

# Commit trained models/configs
cd ../..
git add app/train/
git commit -m "feat: update model weights"
git push origin main
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
git checkout -b training/new-model
# ... train model, update weights ...
git add .
git commit -m "feat: add new trained model"
git push origin training/new-model
cd ..

# Update main repo
git add diri-cyrex
git commit -m "chore: update diri-cyrex with new model"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `git submodule update --init diri-cyrex` | Initialize ML submodule |
| `git submodule update --remote diri-cyrex` | Update to latest ML code |
| `git submodule status diri-cyrex` | Check ML submodule status |
| `cd diri-cyrex && git pull` | Pull latest in submodule |
| `cd diri-cyrex/app/train && ls` | View training scripts |

## 🔗 Related Documentation

- [Main Submodule Guide](./SUBMODULE_COMMANDS.md)
- [README](./README.md)
- [AI Team Guide](./AI_TEAM.md) - Similar workflow

---

**Team**: ML Team  
**Primary Submodule**: `diri-cyrex`  
**Repository**: `git@github.com:Team-Deepiri/diri-cyrex.git`  
**Key Directories**: `app/train/`, `app/ml_models/`, `mlops/`

