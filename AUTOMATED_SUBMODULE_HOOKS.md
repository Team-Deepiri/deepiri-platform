# 🛡️ Automated Git Hooks for All Submodules

## Overview

This system automatically installs and syncs git hooks to **all submodules** whenever you:
- **Checkout** a branch (post-checkout hook)
- **Pull** updates (post-merge hook)

The hooks **automatically reject pushes** to `main`, `dev`, `master`, or team-dev branches in both the main repository and all submodules.

## 🚀 How It Works

### Automatic Installation Flow

```
Developer pulls/clones repo
    ↓
post-checkout or post-merge hook runs
    ↓
1. Installs hooks in main repo (.git/hooks/)
2. Configures hooksPath for main repo
    ↓
3. Reads .gitmodules file
4. For each submodule:
   - Creates .git-hooks/ directory
   - Copies all hooks from main repo
   - Installs hooks in submodule's .git/hooks/
   - Configures hooksPath for submodule
    ↓
All repos now protected! 🎉
```

### Protected Repositories

All of these repositories are automatically protected:

- ✅ **deepiri-platform** (main repo)
- ✅ **deepiri-core-api**
- ✅ **diri-cyrex**
- ✅ **deepiri-web-frontend**
- ✅ **deepiri-api-gateway** (platform-services/backend/deepiri-api-gateway)
- ✅ **deepiri-auth-service** (platform-services/backend/deepiri-auth-service)
- ✅ **deepiri-external-bridge-service** (platform-services/backend/deepiri-external-bridge-service)

### Protected Branches

- `main` - Production branch
- `dev` - Development branch
- `master` - Legacy production branch (protected for compatibility)
- `{repo-name}-team-dev` - Team development branches (automatically detected for repos ending in `-team-dev`)

## 📦 What Gets Installed

Each repository (main + all submodules) gets:

1. **pre-push** - Blocks pushes to protected branches (main, dev, master, and team-dev branches)
2. **post-checkout** - Auto-installs hooks on checkout
3. **post-merge** - Auto-installs hooks on pull

## ✨ For Developers

**Zero configuration required!** Just:

1. **Clone the repo** → Hooks install automatically
2. **Pull updates** → Hooks sync automatically
3. **Try to push to main/dev** → Automatically blocked ❌

### Example Error Message

If you try to push to a protected branch:

```
❌ ERROR: You cannot push directly to 'main'.
   Make a feature branch and use a Pull Request.
   Protected branches: main dev master [team-dev branches]
```

## 🔧 Manual Installation (If Needed)

If you need to manually sync hooks to all submodules:

```bash
cd deepiri
./scripts/sync-hooks-to-submodules.sh
```

Or use the full installation service:

```bash
cd deepiri
./scripts/install-hooks-service.sh
```

## 📝 Technical Details

### Hook Files

- **`.git-hooks/post-checkout`** - Runs on checkout, syncs hooks to submodules
- **`.git-hooks/post-merge`** - Runs on pull, syncs hooks to submodules
- **`.git-hooks/pre-push`** - Blocks pushes to protected branches

### Scripts

- **`scripts/sync-hooks-to-submodules.sh`** - Syncs hooks from main repo to all submodules
- **`scripts/install-hooks-service.sh`** - Full installation service for main repo + all submodules

### How Submodules Are Detected

The hooks automatically read `.gitmodules` to find all submodule paths:

```ini
[submodule "deepiri-core-api"]
	path = deepiri-core-api
	...
```

The hooks extract the `path` value and sync hooks to each submodule.

## ✅ Verification

To verify hooks are installed:

```bash
# Check main repo
cd deepiri
git config core.hooksPath
# Should output: .git-hooks

# Check a submodule
cd deepiri-core-api
git config core.hooksPath
# Should output: .git-hooks

# List installed hooks
ls -la .git/hooks/
# Should show: pre-push, post-checkout, post-merge
```

## 🎯 Benefits

- ✅ **Fully automated** - No manual setup needed
- ✅ **Always up-to-date** - Hooks sync on every pull
- ✅ **Consistent protection** - All repos have the same rules
- ✅ **Zero maintenance** - Works for all developers automatically
- ✅ **Branch protection** - Prevents accidental pushes to main/dev

## 🚨 Troubleshooting

### Hooks not working?

1. **Check if hooks are installed:**
   ```bash
   ls -la .git/hooks/
   ```

2. **Manually run the sync script:**
   ```bash
   ./scripts/sync-hooks-to-submodules.sh
   ```

3. **Verify hooksPath is configured:**
   ```bash
   git config core.hooksPath
   # Should output: .git-hooks
   ```

4. **Check if submodule exists:**
   ```bash
   git submodule status
   ```

### Submodule hooks not syncing?

- Make sure the submodule is initialized: `git submodule update --init`
- Check that `.gitmodules` file exists and is correct
- Verify the submodule path exists in the filesystem

## 📚 Related Documentation

- `GIT_HOOKS_README.md` - General git hooks documentation
- `AUTOMATIC_GIT_HOOKS_SETUP.md` - Original hook setup guide
- `BRANCH_PROTECTION.md` - Branch protection policies

