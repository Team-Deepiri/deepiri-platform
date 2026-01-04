# Frontend Team - Submodule Commands

## 🎯 Required Submodules

The Frontend Team needs access to:
- **deepiri-web-frontend** - Main frontend application

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
./team_submodule_commands/frontend-team/pull_submodules.sh

# OR manually initialize and update frontend submodule
git submodule update --init --recursive deepiri-web-frontend
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/frontend-team/pull_submodules.sh

# OR manually update frontend submodule to latest
git submodule update --remote deepiri-web-frontend
```

## 🔧 Working with Frontend Submodule

### Make Changes to Frontend Code

**⚠️ IMPORTANT: Use the branch naming convention: `firstname_lastname/feature/feature_name` or `firstname_lastname/bug/bug_fix_name`**

```bash
# Navigate to Frontend submodule
cd deepiri-web-frontend

# Create feature branch with your name
# Example: john_doe/feature/add-dashboard-page
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes (components, pages, styles, etc.)
# ... edit files in src/ ...

# Commit changes
git add .
git commit -m "feat: add new component / improve UI"

# Push feature branch
git push origin firstname_lastname/feature/your_feature_name

# Create PR in the deepiri-web-frontend repository
# After PR is merged, return to main repo
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

# Create feature branch first (from frontend root)
cd ../..
git checkout -b firstname_lastname/feature/new-component

# Create or edit components
cd src/components
# ... your work ...

# Commit from frontend root
cd ../..
git add src/components/
git commit -m "feat: new component"
git push origin firstname_lastname/feature/new-component
cd ..
```

### Working on Bug Fixes

```bash
# Navigate to Frontend submodule
cd deepiri-web-frontend

# Create bug fix branch with your name
# Example: jane_smith/bug/fix-styling-issue
git checkout -b firstname_lastname/bug/bug_fix_name

# Make your fixes
# ... edit files ...

# Commit changes
git add .
git commit -m "fix: description of bug fix"

# Push bug fix branch
git push origin firstname_lastname/bug/bug_fix_name

# Create PR in the deepiri-web-frontend repository
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

## 🌿 Branch Naming Convention

**Required Format:**
- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/add-dashboard-page`
- `jane_smith/feature/improve-ui-components`
- `bob_jones/bug/fix-styling-issue`
- `alice_williams/bug/fix-routing-bug`

**Why?**
- Easy to identify who owns the branch
- Clear separation between features and bug fixes
- Better code review organization

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
git checkout -b firstname_lastname/feature/new-page
# ... make changes ...
git add .
git commit -m "feat: new page component"
git push origin firstname_lastname/feature/new-page
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
| `./team_submodule_commands/frontend-team/pull_submodules.sh` | Pull all frontend submodules |
| `git submodule update --init deepiri-web-frontend` | Initialize frontend submodule |
| `git submodule update --remote deepiri-web-frontend` | Update to latest frontend code |
| `git submodule status deepiri-web-frontend` | Check frontend submodule status |
| `cd deepiri-web-frontend && git pull` | Pull latest in submodule |
| `cd deepiri-web-frontend && npm install` | Install frontend dependencies |
| `git checkout -b firstname_lastname/feature/name` | Create feature branch |

## 🔗 Related Documentation

- [Main Submodule Guide](../SUBMODULE_COMMANDS.md)
- [README](../README.md)

---

**Team**: Frontend Team  
**Primary Submodule**: `deepiri-web-frontend`  
**Repository**: `git@github.com:Team-Deepiri/deepiri-web-frontend.git`  
**Key Directories**: `src/components/`, `src/pages/`, `src/api/`  
**Pull Script**: `./team_submodule_commands/frontend-team/pull_submodules.sh`

