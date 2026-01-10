# Exact Git Submodule Commands

## Quick Command Reference

### Step 1: Create New AI Repository
1. Create new repository on GitHub/GitLab: `Deepiri/deepiri-ai`
2. Note the URL: `https://github.com/Deepiri/deepiri-ai.git`

### Step 2: Extract AI Code to New Repository

```bash
# Navigate to main repo
cd deepiri

# Ensure clean working directory
git checkout main
git pull origin main
git status

# Extract diri-cyrex using subtree
git subtree push --prefix=diri-cyrex origin extract-ai-submodule

# Create temporary directory for new repo
cd ..
mkdir deepiri-ai-temp
cd deepiri-ai-temp

# Clone the extracted branch
git clone -b extract-ai-submodule https://github.com/Deepiri/deepiri.git deepiri-ai

# Switch to new repo and update remote
cd deepiri-ai
git remote remove origin
git remote add origin https://github.com/Deepiri/deepiri-ai.git

# Push to new repository (main branch)
git push -u origin extract-ai-submodule:main

# Clean up
cd ../..
rm -rf deepiri-ai-temp
cd deepiri
```

### Step 3: Remove AI Code from Main Repository

```bash
# Remove diri-cyrex from main repo
git checkout main
git rm -r --cached diri-cyrex
git commit -m "refactor: extract diri-cyrex to separate repository"
```

### Step 4: Add as Git Submodule

```bash
# Add the AI repository as a submodule
git submodule add https://github.com/Deepiri/deepiri-ai.git diri-cyrex

# Commit the submodule addition
git commit -m "feat: add diri-cyrex as git submodule"

# Push to main repository
git push origin main
```

### Step 5: Verify Setup

```bash
# Check submodule status
git submodule status

# Test clone (in temporary location)
cd ..
mkdir test-clone && cd test-clone
git clone --recursive https://github.com/Deepiri/deepiri.git test-deepiri
cd test-deepiri
ls diri-cyrex
cd ../..
rm -rf test-clone
cd deepiri
```

## For Team Members (After Migration)

### Existing Clones
```bash
cd deepiri
git pull origin main
git submodule update --init --recursive
```

### New Clones
```bash
git clone --recursive https://github.com/Deepiri/deepiri.git
```

## Working with Submodule

### Make Changes to AI Code
```bash
cd diri-cyrex
# Make changes
git add .
git commit -m "feat: your change"
git push origin main
cd ..
git add diri-cyrex
git commit -m "chore: update AI submodule"
git push origin main
```

### Update to Latest AI Code
```bash
git submodule update --remote diri-cyrex
git add diri-cyrex
git commit -m "chore: update AI submodule"
git push origin main
```

## All-in-One Script (Execute Step by Step)

```bash
# ============================================
# STEP 1: Extract AI Code
# ============================================
cd deepiri
git checkout main
git pull origin main
git subtree push --prefix=diri-cyrex origin extract-ai-submodule

# ============================================
# STEP 2: Create New AI Repository
# ============================================
cd ..
mkdir deepiri-ai-temp && cd deepiri-ai-temp
git clone -b extract-ai-submodule https://github.com/Deepiri/deepiri.git deepiri-ai
cd deepiri-ai
git remote set-url origin https://github.com/Deepiri/deepiri-ai.git
git push -u origin extract-ai-submodule:main
cd ../.. && rm -rf deepiri-ai-temp

# ============================================
# STEP 3: Remove from Main Repo
# ============================================
cd deepiri
git checkout main
git rm -r --cached diri-cyrex
git commit -m "refactor: extract diri-cyrex to separate repository"

# ============================================
# STEP 4: Add as Submodule
# ============================================
git submodule add https://github.com/Deepiri/deepiri-ai.git diri-cyrex
git commit -m "feat: add diri-cyrex as git submodule"
git push origin main

# ============================================
# STEP 5: Verify
# ============================================
git submodule status
```

## Important Notes

- Replace `https://github.com/Deepiri/deepiri-ai.git` with your actual AI repository URL
- Replace `main` with `master` if that's your default branch
- Ensure you have write access to both repositories
- Team members need access to both repositories
- Always use `--recursive` when cloning

