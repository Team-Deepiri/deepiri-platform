# Branch Protection Setup

This repository has **multi-layer protection** for `main` and `dev` branches.

## 🛡️ Protection Layers

### Layer 1: Server-Side CI Blocking (Unbreakable)
- **File**: `.github/workflows/block-direct-push.yml`
- **What it does**: Blocks ANY direct push to `main` or `dev` at the GitHub level
- **Cannot be bypassed**: Even if hooks are removed, this still works
- **Works in**: Free GitHub Organizations, no branch protection needed

### Layer 2: PR Blocking
- **File**: `.github/workflows/block-direct-pr-to-main.yml`
- **What it does**: Blocks Pull Requests targeting `main` or `dev`
- **Forces**: Feature branches → PR → `staging` (or other branches)

### Layer 3: Local Git Hooks (Automatic!)
- **File**: `.git-hooks/pre-push`
- **What it does**: Prevents accidental pushes before they hit GitHub
- **Setup**: **AUTOMATIC** - Hooks are automatically configured via:
  - Post-checkout hook (runs on clone/checkout)
  - Git template directory (if configured globally)
  - Manual setup (backup): Run `./setup-hooks.sh` or `git config core.hooksPath .git-hooks`

### Layer 4: Bot Auto-Close (Optional)
- **File**: `.github/close-protected-prs.yml`
- **What it does**: Auto-closes PRs targeting protected branches (if using Mergify/Probot)
- **Status**: Configuration ready, requires bot installation

## 📋 Protected Branches

- ✅ `main` - Production-ready code only
- ✅ `dev` - Development integration branch

## ✅ Allowed Workflow

1. Create feature branch: `git checkout -b feature/my-feature`
2. Push branch: `git push -u origin feature/my-feature`
3. Open PR into `staging` (NOT `main` or `dev`)
4. CI merges `staging` → `dev` → `main` during deployments

## 🔧 Setup

### Automatic Setup (Default)

**Hooks are automatically configured when you clone the repository!**

The `.git-hooks/` directory and Git configuration are set up automatically. No manual steps required.

### Manual Setup (If Needed)

If hooks aren't working (e.g., existing clone before automatic setup was added), run:

```bash
./setup-hooks.sh
```

Or manually:
```bash
git config core.hooksPath .git-hooks
```

## 📚 Full Documentation

See [CONTRIBUTING.md](./CONTRIBUTING.md) for complete workflow guidelines.

---

**Your `main` and `dev` branches are now bulletproof! 🎉**

