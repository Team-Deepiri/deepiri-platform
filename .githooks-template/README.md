# Git Hooks Template Directory

This directory contains Git hooks that are **automatically installed** when you clone or pull the repository.

## 🚀 Automatic Installation

Hooks are automatically installed using Git's template directory feature. No manual setup required!

### How It Works

1. **On Clone**: Git copies hooks from `.githooks-template/` to `.git/hooks/`
2. **On Checkout/Pull**: The `post-checkout` and `post-merge` hooks ensure hooks are up-to-date
3. **On Push**: The `pre-push` hook blocks pushes to `main`, `master`, or branches containing `team-dev`

### Setup (One-Time, Per Repository)

Run this once per repository to enable automatic installation:

```bash
./scripts/auto-install-hooks.sh
```

Or manually:

```bash
git config init.templateDir .githooks-template
```

### Global Setup (Optional)

To enable automatic hooks for ALL new repositories:

```bash
git config --global init.templateDir "$(pwd)/.githooks-template"
```

## 📦 What Gets Installed

- **post-checkout**: Installs hooks on checkout and configures hooksPath
- **post-merge**: Installs hooks after pull and configures hooksPath  
- **pre-push**: Blocks pushes to `main`, `master`, and branches containing `team-dev`

## ✅ Benefits

- ✅ **Zero manual configuration** after initial setup
- ✅ **Automatic updates** on every pull
- ✅ **Works for all developers** automatically
- ✅ **No global Git config required** (per-repo setup works too)

## 🔧 Troubleshooting

If hooks aren't working:

1. Run the auto-install script: `./scripts/auto-install-hooks.sh`
2. Or manually install: `cp .githooks-template/* .git/hooks/ && chmod +x .git/hooks/*`
3. Configure hooksPath: `git config core.hooksPath .git-hooks`
