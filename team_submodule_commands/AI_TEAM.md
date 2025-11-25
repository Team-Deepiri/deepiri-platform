# AI Team - Submodule Commands

## 🎯 Required Submodules

The AI Team needs access to:
- **diri-cyrex** - AI/ML service (Cyrex)

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri

# Pull latest changes
git pull origin main

# Initialize and update AI submodule
git submodule update --init --recursive diri-cyrex
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Update AI submodule to latest
git submodule update --remote diri-cyrex
```

## 🔧 Working with AI Submodule

### Make Changes to AI Code

```bash
# Navigate to AI submodule
cd diri-cyrex

# Check current branch
git status

# Make your changes
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: your AI feature description"

# Push to AI repository
git push origin main

# Return to main repo
cd ..

# Update main repo to reference new submodule commit
git add diri-cyrex
git commit -m "chore: update diri-cyrex submodule"
git push origin main
```

### Update to Latest AI Code

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

# Check only AI submodule
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

### Working on Feature Branch

```bash
# Create feature branch in submodule
cd diri-cyrex
git checkout -b feature/your-feature
# ... make changes ...
git add .
git commit -m "feat: your feature"
git push origin feature/your-feature
cd ..

# Update main repo
git add diri-cyrex
git commit -m "chore: update diri-cyrex to feature branch"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `git submodule update --init diri-cyrex` | Initialize AI submodule |
| `git submodule update --remote diri-cyrex` | Update to latest AI code |
| `git submodule status diri-cyrex` | Check AI submodule status |
| `cd diri-cyrex && git pull` | Pull latest in submodule |

## 🔗 Related Documentation

- [Main Submodule Guide](./SUBMODULE_COMMANDS.md)
- [README](./README.md)

---

**Team**: AI Team  
**Primary Submodule**: `diri-cyrex`  
**Repository**: `git@github.com:Team-Deepiri/diri-cyrex.git`

