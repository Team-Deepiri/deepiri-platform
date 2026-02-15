# Git Hooks Directory

This directory contains Git hooks that protect the `main`, `dev`, `master`, and branches containing `team-dev`.

## Protected Branches

- **main** - Production branch (exact match)
- **dev** - Development branch (exact match only - branches like `name-dev` or `dev-something` are allowed)
- **master** - Legacy production branch (exact match, protected for compatibility)
- **Any branch containing `team-dev`** - Blocks any branch name that contains the substring `team-dev` (including the dash)

## Automatic Setup

**Git hooks are automatically configured when you clone the repository!**

The `core.hooksPath` is set to `.git-hooks` automatically, so you don't need to run any setup scripts.

## Manual Setup (If Needed)

If hooks aren't working (e.g., for existing clones before automatic setup was added), run:

```bash
./setup-hooks.sh
```

Or manually:
```bash
git config core.hooksPath .git-hooks
```

## Hooks

- **pre-push**: Blocks direct pushes to protected branches:
  - Exact matches: `main`, `dev`, `master`
  - Any branch containing: `team-dev` (e.g., `my-team-dev`, `backend-team-dev`, etc.)
  - Allowed: `name-dev`, `dev-something`, `my-dev-branch` (dev with dashes is fine, but not `team-dev`)
- **post-checkout**: Automatically configures hooksPath on checkout (if not already set)
- **post-merge**: Automatically syncs hooks to submodules on pull

## Testing

Try pushing to a protected branch - you should see an error:
```bash
git checkout main
git push origin main
# ❌ ERROR: You cannot push directly to 'main'.

git checkout dev
git push origin dev
# ❌ ERROR: You cannot push directly to 'dev'.

git checkout my-team-dev
git push origin my-team-dev
# ❌ ERROR: You cannot push to branches containing 'team-dev'.
```

These branches are allowed:
```bash
git checkout name-dev
git push origin name-dev
# ✅ Allowed (dev with dash prefix)

git checkout dev-something
git push origin dev-something
# ✅ Allowed (dev with dash suffix)
```

This confirms hooks are working!

