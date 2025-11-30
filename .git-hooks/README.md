# Git Hooks Directory

This directory contains Git hooks that protect the `main` and `dev` branches.

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

- **pre-push**: Blocks direct pushes to `main` and `dev` branches
- **post-checkout**: Automatically configures hooksPath on checkout (if not already set)

## Testing

Try pushing to main or dev - you should see an error:
```bash
git checkout main
git push origin main
# ❌ ERROR: You cannot push directly to 'main'.
```

This confirms hooks are working!

