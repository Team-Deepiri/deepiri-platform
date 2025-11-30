# Git Hooks Template Directory

This directory contains Git hooks that will be automatically installed when someone clones the repository.

## How It Works

**Option 1: Automatic (Recommended)**

If you set up Git's template directory globally (one-time setup):
```bash
git config --global init.templateDir "$(pwd)/.githooks-template"
```

Then all new Git repositories will automatically get the hooks configured.

**Option 2: Manual Copy**

For existing repositories, copy the hooks:
```bash
cp .githooks-template/post-checkout .git/hooks/post-checkout
chmod +x .git/hooks/post-checkout
```

**Option 3: Use Setup Script**

Run the setup script:
```bash
./setup-hooks.sh
```

## What Gets Configured

The `post-checkout` hook automatically sets:
```gitconfig
[core]
    hooksPath = .git-hooks
```

This ensures all Git hooks use the shared `.git-hooks/` directory.
