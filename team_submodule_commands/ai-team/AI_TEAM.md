# AI Team - Submodule Commands

## 🎯 Required Submodules

The AI Team needs access to:
- **diri-cyrex** - AI/ML service (Cyrex)

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
./team_submodule_commands/ai-team/pull_submodules.sh

# OR manually initialize and update AI submodule
git submodule update --init --recursive diri-cyrex
```

### Daily Workflow

```bash
# Update main repo
git pull origin main

# Run the pull script (recommended)
./team_submodule_commands/ai-team/pull_submodules.sh

# OR manually update AI submodule to latest
git submodule update --remote diri-cyrex
```

## 🔧 Working with AI Submodule

### Make Changes to AI Code

**⚠️ IMPORTANT: Use the branch naming convention: `firstname_lastname/feature/feature_name` or `firstname_lastname/bug/bug_fix_name`**

```bash
# Navigate to AI submodule
cd diri-cyrex

# Create feature branch with your name
# Example: john_doe/feature/improve-classifier
git checkout -b firstname_lastname/feature/your_feature_name

# Make your changes
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: your AI feature description"

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

### Working on Bug Fixes

```bash
# Navigate to AI submodule
cd diri-cyrex

# Create bug fix branch with your name
# Example: jane_smith/bug/fix-memory-leak
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

## 🌿 Branch Naming Convention

**Required Format:**
- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/improve-intent-classifier`
- `jane_smith/feature/add-rag-optimization`
- `bob_jones/bug/fix-memory-leak`
- `alice_williams/bug/fix-api-timeout`

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

### Working on Feature Branch

```bash
# Create feature branch in submodule
cd diri-cyrex
git checkout -b firstname_lastname/feature/your-feature
# ... make changes ...
git add .
git commit -m "feat: your feature"
git push origin firstname_lastname/feature/your-feature
cd ..

# Update main repo
git add diri-cyrex
git commit -m "chore: update diri-cyrex to feature branch"
```

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `./team_submodule_commands/ai-team/pull_submodules.sh` | Pull all AI submodules |
| `git submodule update --init diri-cyrex` | Initialize AI submodule |
| `git submodule update --remote diri-cyrex` | Update to latest AI code |
| `git submodule status diri-cyrex` | Check AI submodule status |
| `cd diri-cyrex && git pull` | Pull latest in submodule |
| `git checkout -b firstname_lastname/feature/name` | Create feature branch |

## 🔗 Related Documentation

- [Main Submodule Guide](../SUBMODULE_COMMANDS.md)
- [README](../README.md)

---

**Team**: AI Team  
**Primary Submodule**: `diri-cyrex`  
**Repository**: `git@github.com:Team-Deepiri/diri-cyrex.git`  
**Pull Script**: `./team_submodule_commands/ai-team/pull_submodules.sh`

