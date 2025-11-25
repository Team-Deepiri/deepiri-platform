# Frontend Team - Submodule Commands

## 🎯 Required Submodules

The Frontend Team needs access to:
- **deepiri-web-frontend** - Main frontend application

## 📥 After Pulling Main Repo

### First Time Setup

```bash
# Navigate to main repository
cd deepiri

# Pull latest changes
git pull origin main

# Initialize and update frontend submodule
git submodule update --init --recursive deepiri-web-frontend
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Update frontend submodule to latest
git submodule update --remote deepiri-web-frontend
```

## 🔧 Working with Frontend Submodule

### Make Changes to Frontend Code

```bash
# Navigate to Frontend submodule
cd deepiri-web-frontend

# Check current branch
git status

# Make your changes (components, pages, styles, etc.)
# ... edit files in src/ ...

# Commit changes
git add .
git commit -m "feat: add new component / improve UI"

# Push to Frontend repository
git push origin main

# Return to main repo
cd ..

# Update main repo to reference new submodule commit
git add deepiri-web-frontend
git commit -m "chore: update web-frontend submodule"
git push origin main
```

### Working with Components

```bash
# Navigate to components directory
cd deepiri-web-frontend/src/components

# Create or edit components
# ... your work ...

# Commit from frontend root
cd ../..
git add src/components/
git commit -m "feat: new component"
git push origin main
cd ..
```

### Update to Latest Frontend Code

```bash
# From main repo root
git submodule update --remote deepiri-web-frontend

# Review changes
cd deepiri-web-frontend
git log --oneline -10
cd ..

# Commit submodule update
git add deepiri-web-frontend
git commit -m "chore: update web-frontend to latest"
git push origin main
```

### Check Submodule Status

```bash
# Check all submodules
git submodule status

# Check only frontend submodule
git submodule status deepiri-web-frontend
```

## 🐛 Troubleshooting

### Submodule Not Initialized

```bash
# If you see empty directory
git submodule update --init deepiri-web-frontend
```

### Submodule Out of Sync

```bash
# If submodule shows as modified but you haven't changed anything
cd deepiri-web-frontend
git checkout main
git pull origin main
cd ..
git add deepiri-web-frontend
git commit -m "chore: sync web-frontend submodule"
```

### Working on Feature Branch

```bash
# Create feature branch in submodule
cd deepiri-web-frontend
git checkout -b feature/new-page
# ... make changes ...
git add .
git commit -m "feat: new page component"
git push origin feature/new-page
cd ..

# Update main repo
git add deepiri-web-frontend
git commit -m "chore: update web-frontend to feature branch"
```

### Node Modules Issues

```bash
# If node_modules are out of sync
cd deepiri-web-frontend
rm -rf node_modules package-lock.json
npm install
cd ..
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `git submodule update --init deepiri-web-frontend` | Initialize frontend submodule |
| `git submodule update --remote deepiri-web-frontend` | Update to latest frontend code |
| `git submodule status deepiri-web-frontend` | Check frontend submodule status |
| `cd deepiri-web-frontend && git pull` | Pull latest in submodule |
| `cd deepiri-web-frontend && npm install` | Install frontend dependencies |

## 🔗 Related Documentation

- [Main Submodule Guide](./SUBMODULE_COMMANDS.md)
- [README](./README.md)

---

**Team**: Frontend Team  
**Primary Submodule**: `deepiri-web-frontend`  
**Repository**: `git@github.com:Team-Deepiri/deepiri-web-frontend.git`  
**Key Directories**: `src/components/`, `src/pages/`, `src/api/`

