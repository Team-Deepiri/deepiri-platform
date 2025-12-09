# 🛡️ Automatic Git Hooks - Branch Protection

**Zero configuration required!** Git hooks automatically install and configure themselves on every checkout and pull.

## 🚀 How It Works

The hooks use a **self-installing** mechanism:

1. **Template Hooks** (`.githooks-template/`): Installed on clone via Git's template directory
2. **Managed Hooks** (`.git-hooks/`): Source of truth for all hooks
3. **Active Hooks** (`.git/hooks/`): Automatically installed/updated by post-checkout and post-merge

### Automatic Installation Flow

```
Developer clones repo
    ↓
Git copies .githooks-template/* → .git/hooks/
    ↓
post-checkout runs → copies .git-hooks/* → .git/hooks/
    ↓
Developer pulls
    ↓
post-merge runs → updates .git-hooks/* → .git/hooks/
    ↓
Developer tries to push to main/dev
    ↓
pre-push blocks ❌
```

## 📦 Protected Repositories

All repos have automatic branch protection:

- ✅ `deepiri-platform`
- ✅ `deepiri-core-api`
- ✅ `deepiri-web-frontend`
- ✅ `deepiri-api-gateway`
- ✅ `deepiri-auth-service`
- ✅ `deepiri-external-bridge-service`
- ✅ `diri-cyrex`

## 🛡️ Protected Branches

- `main` - Production branch
- `dev` - Development branch

## ✨ For Developers

**Do nothing!** Hooks work automatically:

- Clone a repo → hooks install automatically
- Pull updates → hooks update automatically
- Try to push to main/dev → automatically blocked

## 🔧 For Repository Maintainers

### One-Time Setup (Per Repository)

Enable template hooks for automatic installation on clone:

```bash
git config init.templateDir .githooks-template
```

Or use the helper script:

```bash
./scripts/auto-install-hooks.sh
```

### Verify Setup

```bash
# Check if template is configured
git config init.templateDir

# Should show: .githooks-template
```

## 🧪 Testing

```bash
# Try to push to main (should fail)
git checkout main
git push origin main
# ❌ ERROR: You cannot push directly to 'main'.
```

## 📁 Hook Structure

```
.git-hooks/              # Source of truth (committed)
├── pre-push            # Blocks main/dev pushes
├── post-checkout        # Auto-installs hooks on checkout
└── post-merge          # Auto-installs hooks on pull

.githooks-template/      # Template for new clones
├── post-checkout        # Installed to .git/hooks/ on clone
└── post-merge          # Installed to .git/hooks/ on clone

.git/hooks/              # Active hooks (auto-generated)
├── pre-push            # Copied from .git-hooks/
├── post-checkout        # Copied from template, then from .git-hooks/
└── post-merge          # Copied from template, then from .git-hooks/
```

## 🔄 Self-Installing Mechanism

The `post-checkout` and `post-merge` hooks in `.git-hooks/` automatically:

1. Check if hooks exist in `.git/hooks/`
2. Copy all hooks from `.git-hooks/` to `.git/hooks/` if missing or outdated
3. Make them executable
4. Configure `core.hooksPath = .git-hooks`

This ensures:
- ✅ Hooks work even without `core.hooksPath` set initially
- ✅ Hooks update automatically on every pull
- ✅ No manual intervention required

## 🐛 Troubleshooting

### Hooks not running?

1. **Check if hooks exist**: `ls -la .git/hooks/`
2. **Trigger installation**: `git checkout -b test && git checkout -` (runs post-checkout)
3. **Or pull**: `git pull` (runs post-merge)

### Template not working?

If new clones don't get hooks automatically:

```bash
# Set template directory
git config init.templateDir .githooks-template

# Or globally (affects all new repos)
git config --global init.templateDir "$(pwd)/.githooks-template"
```

### Still not working?

Manually install hooks:

```bash
# Copy hooks manually
cp .git-hooks/* .git/hooks/
chmod +x .git/hooks/*
git config core.hooksPath .git-hooks
```

## 🎉 Summary

- **Developers**: Zero setup - hooks work automatically
- **Maintainers**: One-time template setup per repo
- **Protection**: Automatic on every checkout and pull
- **Updates**: Automatic on every pull

Your `main` and `dev` branches are now bulletproof! 🎯

