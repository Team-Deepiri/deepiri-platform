# 🚀 Automatic Git Hooks - Zero Configuration Required

Git hooks are **100% automatic** - your developers don't need to do anything! Hooks install and configure themselves on every checkout and pull.

## ✨ How It Works (Fully Automatic)

1. **On Checkout/Clone**: The `post-checkout` hook automatically installs all hooks from `.git-hooks/` into `.git/hooks/`
2. **On Pull**: The `post-merge` hook automatically installs/updates hooks from `.git-hooks/` into `.git/hooks/`
3. **On Push**: The `pre-push` hook blocks pushes to `main` or `dev` branches

## 🎯 Zero Setup Required

**Developers don't need to run any scripts!** The hooks install themselves automatically:

- ✅ **First clone**: Hooks install automatically via template directory
- ✅ **Every checkout**: Hooks update automatically via `post-checkout`
- ✅ **Every pull**: Hooks update automatically via `post-merge`
- ✅ **No manual configuration**: Everything happens automatically

## 📦 Protected Repositories

All Deepiri repositories have automatic branch protection:

- ✅ `deepiri-platform` (main repo)
- ✅ `deepiri-core-api`
- ✅ `deepiri-web-frontend`
- ✅ `deepiri-api-gateway`
- ✅ `deepiri-auth-service`
- ✅ `deepiri-external-bridge-service`
- ✅ `diri-cyrex`

## 🛡️ Protected Branches

The following branches are protected in all repositories:
- `main` - Production branch
- `dev` - Development branch

## 🔄 Automatic Installation Flow

```
Developer clones repo
    ↓
Git copies hooks from .githooks-template/ to .git/hooks/
    ↓
post-checkout hook runs → installs hooks from .git-hooks/ to .git/hooks/
    ↓
Developer pulls updates
    ↓
post-merge hook runs → updates hooks from .git-hooks/ to .git/hooks/
    ↓
Developer tries to push to main/dev
    ↓
pre-push hook blocks the push ❌
```

## 🧪 Testing

To verify hooks are working automatically:

```bash
# Clone a repo (hooks install automatically)
git clone <repo-url>
cd <repo>

# Try to push to main (should fail automatically)
git checkout main
git push origin main
# ❌ ERROR: You cannot push directly to 'main'.
```

## 🔧 One-Time Setup (Repository Maintainers Only)

If you're setting up a new repository, run this once to enable template hooks:

```bash
git config init.templateDir .githooks-template
```

Or use the helper script:

```bash
./scripts/auto-install-hooks.sh
```

**Note**: This is only needed once per repository. After that, all developers get hooks automatically!

## 📝 How Hooks Self-Install

The `post-checkout` and `post-merge` hooks in `.git-hooks/` automatically:

1. Check if hooks exist in `.git/hooks/`
2. Copy all hooks from `.git-hooks/` to `.git/hooks/` if missing or outdated
3. Make them executable
4. Configure `core.hooksPath` to use `.git-hooks`

This means:
- ✅ Hooks work even if `core.hooksPath` isn't set
- ✅ Hooks update automatically when you pull changes
- ✅ No manual intervention required

## 🎉 Benefits

- ✅ **Zero developer setup** - works automatically
- ✅ **Automatic updates** - hooks update on every pull
- ✅ **Self-healing** - hooks reinstall if deleted
- ✅ **Consistent protection** - all repos protected the same way
- ✅ **No global config** - works per-repository

## 🐛 Troubleshooting

### Hooks not running?

1. Check if hooks exist: `ls -la .git/hooks/`
2. If missing, checkout a branch: `git checkout -b test && git checkout -`
3. Or pull: `git pull` (triggers post-merge)

### Still not working?

The hooks should install automatically, but if needed:

```bash
# Manually trigger hook installation
git checkout -b temp && git checkout -
```

This triggers `post-checkout` which installs the hooks.

## 🎯 Summary

**For Developers**: Do nothing! Hooks work automatically.

**For Maintainers**: Set up template directory once, then all developers get automatic protection forever.
