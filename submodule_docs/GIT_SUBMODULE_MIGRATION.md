# Git Submodule Migration Guide - AI Code Separation

This guide provides exact commands to separate the AI-related code (`diri-cyrex/`) into its own repository and add it back as a git submodule.

## Prerequisites

- Git installed and configured
- Access to create a new repository (GitHub/GitLab/etc.)
- Backup of your current repository (recommended)

## Step 1: Create a New Repository for AI Code

1. **Create a new repository** (e.g., `Deepiri/deepiri-ai` or `Deepiri/ai-backend`)
   - On GitHub: Go to your organization/user → New Repository
   - Name it: `deepiri-ai` (or your preferred name)
   - **Do NOT initialize with README, .gitignore, or license** (we'll bring our own)

2. **Note the repository URL**:
   ```
   https://github.com/Deepiri/deepiri-ai.git
   ```
   (Replace with your actual repository URL)

## Step 2: Extract AI Code Using Git Subtree (Recommended Method)

This method preserves history and is simpler than filter-branch.

### 2.1: Ensure you're on the main branch with clean working directory

```bash
cd deepiri
git checkout main  # or master, depending on your default branch
git pull origin main
git status  # Ensure working directory is clean
```

### 2.2: Create a temporary branch for the extraction

```bash
git checkout -b extract-ai-submodule
```

### 2.3: Extract diri-cyrex using git subtree

```bash
# Extract diri-cyrex directory to a new branch
git subtree push --prefix=diri-cyrex origin extract-ai-submodule
```

**Note:** If you get an error about the branch not existing, create it first:
```bash
git push origin extract-ai-submodule
```

### 2.4: Create the new AI repository from the extracted branch

```bash
# Create a temporary directory
cd ..
mkdir deepiri-ai-temp
cd deepiri-ai-temp

# Clone the extracted branch
git clone -b extract-ai-submodule https://github.com/Deepiri/deepiri.git deepiri-ai

# Remove the old remote and add the new AI repository remote
cd deepiri-ai
git remote remove origin
git remote add origin https://github.com/Deepiri/deepiri-ai.git

# Push to the new repository
git push -u origin extract-ai-submodule:main
```

### 2.5: Clean up temporary files

```bash
cd ../..
rm -rf deepiri-ai-temp
cd deepiri
```

## Step 3: Remove AI Code from Main Repository

### 3.1: Remove diri-cyrex from main repository

```bash
cd deepiri
git checkout main

# Remove the directory from git (but keep it locally temporarily)
git rm -r --cached diri-cyrex

# Commit the removal
git commit -m "refactor: extract diri-cyrex to separate repository for submodule migration"
```

### 3.2: (Optional) Remove AI-specific documentation if you want to move it too

If you want to move AI docs to the AI repository:

```bash
# Move AI-specific docs (optional - adjust paths as needed)
git mv docs/AI_*.md docs/README_AI_TEAM.md docs/AI_TEAM_*.md temp-ai-docs/
# Then later move these to the AI repo
```

For now, we'll keep the docs in the main repo for reference.

## Step 4: Add AI Repository as Git Submodule

### 4.1: Add the submodule

```bash
cd deepiri
git submodule add https://github.com/Deepiri/deepiri-ai.git diri-cyrex
```

This will:
- Clone the AI repository into `diri-cyrex/`
- Create a `.gitmodules` file
- Stage the submodule addition

### 4.2: Commit the submodule addition

```bash
git commit -m "feat: add diri-cyrex as git submodule"
```

### 4.3: Push changes to main repository

```bash
git push origin main
```

## Step 5: Update .gitignore (if needed)

The `diri-cyrex/` directory is now a submodule, so ensure your `.gitignore` doesn't accidentally ignore it:

```bash
# Check if diri-cyrex is in .gitignore
grep -n "diri-cyrex" .gitignore

# If it's there and you want to remove it:
# Edit .gitignore and remove any lines that ignore diri-cyrex/
```

## Step 6: Verify the Setup

### 6.1: Check submodule status

```bash
git submodule status
```

You should see:
```
<commit-hash> diri-cyrex (heads/main)
```

### 6.2: Test cloning the main repository with submodule

```bash
# Test in a temporary location
cd ..
mkdir test-clone
cd test-clone
git clone --recursive https://github.com/Deepiri/deepiri.git test-deepiri
cd test-deepiri
ls diri-cyrex  # Should show the AI code
cd ../..
rm -rf test-clone
```

## Step 7: Update Team Workflows

### 7.1: For existing clones

Team members with existing clones need to:

```bash
cd deepiri
git pull origin main
git submodule update --init --recursive
```

### 7.2: For new clones

Always clone with `--recursive`:

```bash
git clone --recursive https://github.com/Deepiri/deepiri.git
```

Or if already cloned:

```bash
git clone https://github.com/Deepiri/deepiri.git
cd deepiri
git submodule update --init --recursive
```

## Step 8: Working with the Submodule

### 8.1: Making changes to AI code

```bash
cd diri-cyrex
# Make your changes
git add .
git commit -m "feat: add new AI feature"
git push origin main

# Go back to main repo
cd ..
git add diri-cyrex
git commit -m "chore: update AI submodule"
git push origin main
```

### 8.2: Updating to latest AI code in main repo

```bash
cd diri-cyrex
git pull origin main
cd ..
git add diri-cyrex
git commit -m "chore: update AI submodule to latest"
git push origin main
```

### 8.3: Updating AI submodule from main repo

```bash
git submodule update --remote diri-cyrex
git add diri-cyrex
git commit -m "chore: update AI submodule to latest"
```

## Alternative Method: Using Git Filter-Branch (More Complex)

If you prefer a cleaner history extraction, you can use `git filter-branch`:

```bash
# Create a new clone for safety
cd ..
git clone https://github.com/Deepiri/deepiri.git deepiri-ai-extract
cd deepiri-ai-extract

# Extract only diri-cyrex history
git filter-branch --prune-empty --subdirectory-filter diri-cyrex main

# Add new remote
git remote remove origin
git remote add origin https://github.com/Deepiri/deepiri-ai.git

# Push to new repository
git push -u origin main

# Clean up
cd ..
rm -rf deepiri-ai-extract
cd deepiri
```

Then continue with Step 3 onwards.

## Troubleshooting

### Issue: Submodule shows as modified when it shouldn't

```bash
# Update submodule to match the committed version
git submodule update --init --recursive
```

### Issue: Can't push to submodule

```bash
# Ensure you have write access to the AI repository
# Check remote URL
cd diri-cyrex
git remote -v
```

### Issue: Submodule is empty after clone

```bash
# Initialize and update submodules
git submodule update --init --recursive
```

### Issue: Need to change submodule URL

```bash
# Edit .gitmodules file
# Then run:
git submodule sync
git submodule update --init --recursive
```

## Summary of Commands (Quick Reference)

```bash
# 1. Extract AI code
cd deepiri
git checkout -b extract-ai-submodule
git subtree push --prefix=diri-cyrex origin extract-ai-submodule

# 2. Create new AI repo (do this on GitHub/GitLab first)
# Then:
cd ..
mkdir deepiri-ai-temp && cd deepiri-ai-temp
git clone -b extract-ai-submodule https://github.com/Deepiri/deepiri.git deepiri-ai
cd deepiri-ai
git remote set-url origin https://github.com/Deepiri/deepiri-ai.git
git push -u origin extract-ai-submodule:main
cd ../.. && rm -rf deepiri-ai-temp

# 3. Remove from main repo
cd deepiri
git checkout main
git rm -r --cached diri-cyrex
git commit -m "refactor: extract diri-cyrex to separate repository"

# 4. Add as submodule
git submodule add https://github.com/Deepiri/deepiri-ai.git diri-cyrex
git commit -m "feat: add diri-cyrex as git submodule"
git push origin main

# 5. For team members
git pull origin main
git submodule update --init --recursive
```

## Next Steps

1. Update CI/CD pipelines to handle submodules
2. Update documentation to mention the submodule structure
3. Set up access controls on the AI repository
4. Update Docker Compose files if they reference diri-cyrex paths
5. Consider moving AI-specific documentation to the AI repository

## Notes

- The AI repository will have its own version history
- Team members need access to both repositories
- CI/CD needs to be configured to handle submodules
- The main repository will track a specific commit of the AI repository

