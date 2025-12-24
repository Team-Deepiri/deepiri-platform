# 🚀 Complete Setup Guide - Deepiri

**This is the definitive guide for setting up and running the entire Deepiri project from scratch.**

This guide covers:
- ✅ All prerequisites and dependencies
- ✅ Complete environment setup
- ✅ Building all services
- ✅ Running the entire stack
- ✅ Verification and testing

## Quick Reference

### Setup Minikube (ONLY FOR PRODUCTION / USING  Kubernetes/Skaffold builds)
```bash
# Check if Minikube is running
minikube status

# If not running, start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### Build
```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Or use build script
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell
```

### When you DO need to build / rebuild
Only build if:
1. **Dockerfile changes**
2. **package.json/requirements.txt changes** (dependencies)
3. **First time setup**

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!


## TYPICALLY JUST USE DOCKER / DOCKER COMPOSE / PYTHON IMPORTING DOCKER UTILS, --> FOR LOCAL DEV WORK!!!:

### Run all services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop all services
```bash
docker compose -f docker-compose.dev.yml down
```

### Running only services you need for your team
```bash
docker compose -f docker-compose.<team_name>-team.yml up -d
# Examples:
docker compose -f docker-compose.ai-team.yml up -d
docker compose -f docker-compose.backend-team.yml up -d
docker compose -f docker-compose.frontend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.<team_name>-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f auth-service
# ... etc for all services
```

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Initial Setup](#initial-setup)
4. [Git Hooks Setup](#git-hooks-setup)
5. [Submodule Management](#submodule-management)
6. [Team Development Environments](#team-development-environments)
7. [Docker Setup](#docker-setup)
8. [Kubernetes Setup (Skaffold)](#kubernetes-setup-skaffold)
9. [Environment Configuration](#environment-configuration)
10. [Building All Services](#building-all-services)
11. [Running the Application](#running-the-application)
12. [Verification](#verification)
13. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

Before starting, ensure you have the following installed:

| Software | Version | Purpose |
|----------|---------|---------|
| **Docker** | 20.10+ | Container runtime |
| **Docker Compose** | 2.0+ | Multi-container orchestration |
| **Minikube** | Latest | Local Kubernetes cluster |
| **Skaffold** | Latest | Kubernetes development tool |
| **kubectl** | Latest | Kubernetes CLI |
| **Git** | 2.30+ | Version control |
| **Node.js** | 20.x+ | Frontend and backend services |
| **Python** | 3.11+ | AI/ML services (optional for local dev) |

### Required Accounts & API Keys

- **OpenAI API Key** (or Anthropic API Key) - for AI features
- **MongoDB Atlas** (optional) - cloud database, or use local MongoDB
- **Firebase Account** (optional) - for authentication
- **GitHub Account** - for repository access

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker-compose --version

# Check Kubernetes tools
minikube version
kubectl version --client
skaffold version

# Check Node.js (should be 20.x or higher)
node --version
npm --version

# Check Python (should be 3.11+)
python3 --version

# Check Git
git --version
```

---

## System Requirements

### Minimum Requirements

- **RAM:** 8GB (16GB+ recommended)
- **Storage:** 50GB+ free space
- **CPU:** 4 cores (8+ recommended)
- **OS:** 
  - Windows 10+ with WSL2 (recommended)
  - Linux (Ubuntu 20.04+)
  - macOS 10.15+

### GPU Requirements (Optional)

- **For GPU acceleration:** NVIDIA GPU with CUDA 11.8+
- **For CPU-only builds:** Any modern CPU (Intel Iris Xe, AMD, etc.)
- **Note:** Intel Iris Xe Graphics does NOT support CUDA - use CPU profile

---

## Initial Setup

### 1. Clone the Repository

```bash
# Clone the repository with all submodules
git clone --recursive <repository-url>
cd Deepiri/deepiri

# Verify you're in the correct directory
ls -la
# You should see: skaffold.yaml, docker-compose.yml, platform-services/, team_submodule_commands/, team_dev_environments/, etc.
```

**Important:** Use `--recursive` to clone all submodules, or run `git submodule update --init --recursive` after cloning.

### 2. Install System Dependencies

**For WSL2/Ubuntu/Debian:**

```bash
# Update package list
sudo apt update

# Install essential build tools
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release
```

**For macOS:**

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install curl wget git
```

### 3. Set Up Git Hooks (Required)

**⚠️ CRITICAL:** Git hooks must be set up before proceeding. They protect critical branches from accidental pushes.

```bash
# From repository root
./scripts/fix-all-git-hooks.sh

# Verify hooks are working
git config core.hooksPath
# Should output: .git-hooks
```

See [Git Hooks Setup](#git-hooks-setup) section for detailed information.

### 4. Set Up Your Team's Submodules

Each team only needs specific submodules. Pull only what you need:

```bash
# Navigate to your team's submodule commands directory
cd team_submodule_commands/<your-team>

# Pull your team's submodules
./pull_submodules.sh

# Set up hooks in your submodules
./setup-hooks.sh
```

See [Submodule Management](#submodule-management) section for detailed information.

### 5. Set Up Your Team's Development Environment

```bash
# Install Python dependencies (for team dev environments)
pip install pyyaml

# Navigate to your team's dev environment
cd team_dev_environments/<your-team>

# Build your services (first time only)
./build.sh
```

See [Team Development Environments](#team-development-environments) section for detailed information.

---

## Git Hooks Setup

### ⚠️ **CRITICAL: Git Hooks Must Be Set Up First**

Git hooks protect critical branches (`main`, `dev`, `master`, and team-dev branches) from accidental direct pushes. **This setup is required for all team members.**

### Automatic Setup (Recommended)

Git hooks are **automatically configured** when you clone the repository. The `post-checkout` hook sets `core.hooksPath` to `.git-hooks` automatically.

**Verify hooks are working:**
```bash
# Check if hooks are configured
git config core.hooksPath
# Should output: .git-hooks

# Test hooks (should fail)
git checkout main
git push origin main
# ❌ ERROR: You cannot push directly to 'main'.
```

### Manual Setup (If Needed)

If hooks aren't working (e.g., for existing clones), run:

```bash
# From repository root
./scripts/fix-all-git-hooks.sh

# Or manually
git config core.hooksPath .git-hooks
```

### Team-Specific Hook Setup

Each team can sync hooks to their specific submodules:

```bash
# Navigate to your team's submodule commands directory
cd team_submodule_commands/<your-team>

# Run the setup-hooks script
./setup-hooks.sh
```

**Available teams:**
- `team_submodule_commands/ai-team/setup-hooks.sh`
- `team_submodule_commands/backend-team/setup-hooks.sh`
- `team_submodule_commands/frontend-team/setup-hooks.sh`
- `team_submodule_commands/infrastructure-team/setup-hooks.sh`
- `team_submodule_commands/ml-team/setup-hooks.sh`
- `team_submodule_commands/qa-team/setup-hooks.sh`
- `team_submodule_commands/platform-engineers/setup-hooks.sh`

### What the Hooks Do

1. **pre-push**: Blocks direct pushes to protected branches
   - Protected branches: `main`, `dev`, `master`, `*-team-dev`
   - Forces use of pull requests for code review

2. **post-checkout**: Automatically configures hooks on checkout
   - Sets `core.hooksPath` if not already configured
   - Ensures hooks work in all branches

3. **post-merge**: Syncs hooks to submodules after pull
   - Copies hooks to submodules
   - Configures `core.hooksPath` in submodules
   - Handles `.git` as file (submodule) vs directory correctly

### Protected Branches

**⚠️ You cannot push directly to these branches:**
- `main` - Production branch
- `dev` - Development branch
- `master` - Legacy production branch
- `*-team-dev` - Team development branches (e.g., `backend-team-dev`)

**✅ Workflow:**
1. Create a feature branch: `git checkout -b firstname_lastname/feature/feature-name`
2. Make your changes and commit
3. Push your branch: `git push origin firstname_lastname/feature/feature-name`
4. Create a Pull Request to merge into `main` or `dev`

### Troubleshooting Git Hooks

**Hooks not working?**
```bash
# Check if hooksPath is set
git config core.hooksPath

# If empty, set it manually
git config core.hooksPath .git-hooks

# Verify hooks exist
ls -la .git-hooks/

# Make hooks executable
chmod +x .git-hooks/*
```

**Submodule hooks not syncing?**
```bash
# Run the fix script
./scripts/fix-all-git-hooks.sh

# Or manually sync to a specific submodule
cd <submodule-path>
git config core.hooksPath .git-hooks
cd ..
```

---

## Submodule Management

### Overview

The Deepiri project uses Git submodules to manage multiple repositories. Each team only needs to work with their specific submodules.

### First-Time Setup

```bash
# Clone the repository with all submodules
git clone --recursive <repository-url>
cd Deepiri/deepiri

# OR if you already cloned without submodules
git submodule update --init --recursive
```

### Team-Specific Submodule Setup

Each team has a dedicated script to pull only the submodules they need:

```bash
# Navigate to your team's submodule commands directory
cd team_submodule_commands/<your-team>

# Run the pull script
./pull_submodules.sh
```

**Available teams and their submodules:**

| Team | Script | Submodules |
|------|--------|------------|
| **AI Team** | `team_submodule_commands/ai-team/pull_submodules.sh` | `diri-cyrex`, `deepiri-external-bridge-service` |
| **ML Team** | `team_submodule_commands/ml-team/pull_submodules.sh` | `diri-cyrex` |
| **Backend Team** | `team_submodule_commands/backend-team/pull_submodules.sh` | `deepiri-core-api`, `deepiri-api-gateway`, `deepiri-auth-service`, `deepiri-external-bridge-service`, `deepiri-web-frontend` |
| **Frontend Team** | `team_submodule_commands/frontend-team/pull_submodules.sh` | `deepiri-web-frontend`, `deepiri-auth-service`, `deepiri-api-gateway` |
| **Infrastructure Team** | `team_submodule_commands/infrastructure-team/pull_submodules.sh` | All except `deepiri-web-frontend` |
| **QA Team** | `team_submodule_commands/qa-team/pull_submodules.sh` | All submodules (for comprehensive testing) |
| **Platform Engineers** | `team_submodule_commands/platform-engineers/pull_submodules.sh` | All submodules (platform management) |

### After Pulling Main Repository

```bash
# Update main repository
git pull origin main

# Update your team's submodules
cd team_submodule_commands/<your-team>
./pull_submodules.sh
```

### Working with Submodules

**Check submodule status:**
```bash
# Check all submodules
git submodule status

# Check specific submodule
git submodule status <submodule-path>
```

**Update submodules:**
```bash
# Update all submodules to latest
git submodule update --remote --recursive

# Update specific submodule
git submodule update --remote <submodule-path>
```

**Work inside a submodule:**
```bash
# Navigate to submodule
cd <submodule-path>

# Create feature branch (follow naming convention!)
git checkout -b firstname_lastname/feature/your_feature_name

# Make changes, commit, and push
git add .
git commit -m "feat: your change"
git push origin firstname_lastname/feature/your_feature_name

# Return to main repo
cd ..

# Update main repo to reference new submodule commit
git add <submodule-path>
git commit -m "chore: update <submodule-name>"
git push origin main
```

### Branch Naming Convention

**⚠️ REQUIRED FOR ALL TEAMS:**

All feature and bug fix branches must follow this naming convention:
- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/add-user-authentication`
- `jane_smith/feature/improve-api-performance`
- `bob_jones/bug/fix-database-connection-pool`

### Setting Up Hooks in Submodules

After pulling submodules, sync hooks to them:

```bash
# From your team's submodule commands directory
cd team_submodule_commands/<your-team>
./setup-hooks.sh
```

This will:
- Copy hooks from main repo to your team's submodules
- Configure `core.hooksPath` in each submodule
- Ensure submodules are protected from direct pushes

### Common Submodule Commands

```bash
# Initialize all submodules
git submodule update --init --recursive

# Update all submodules to latest commits
git submodule update --remote --recursive

# Update specific submodule
git submodule update --remote <submodule-path>

# Check submodule status
git submodule status

# Enter submodule directory
cd <submodule-path>

# Return to main repo
cd ../..
```

### Troubleshooting Submodules

**Submodule not found?**
```bash
# Initialize and update
git submodule update --init --recursive <submodule-path>
```

**Submodule out of sync?**
```bash
# Update to latest
git submodule update --remote <submodule-path>
```

**Submodule hooks not working?**
```bash
# Run team setup-hooks script
cd team_submodule_commands/<your-team>
./setup-hooks.sh
```

For complete submodule documentation, see [team_submodule_commands/README.md](team_submodule_commands/README.md).

---

## Team Development Environments

### Overview

Each team has a dedicated development environment with scripts to build and run only the services they need. This saves resources and simplifies development.

### Directory Structure

```
team_dev_environments/
├── shared/                          # Shared utilities
│   ├── k8s_env_loader.py           # Loads k8s ConfigMaps & Secrets
│   ├── docker_utils.py              # Docker helper functions
│   └── service_definitions.py       # Service definitions
│
├── ai-team/                         # AI Team environment
│   ├── run.py                       # ⭐ Python runner (recommended)
│   ├── start.sh / start.ps1        # Shell alternatives
│   ├── build.sh                     # Build script
│   ├── stop.sh                      # Stop script
│   └── README.md                    # Team-specific docs
│
├── backend-team/                    # Backend Team environment
├── frontend-team/                   # Frontend Team environment
├── infrastructure-team/             # Infrastructure Team environment
├── ml-team/                         # ML Team environment
├── platform-engineers/              # Platform Engineers environment
└── qa-team/                         # QA Team environment
```

### One-Time Setup

**Before using any team environment:**

1. **Set up Git hooks** (from repository root):
   ```bash
   ./scripts/fix-all-git-hooks.sh
   ```

2. **Install Python dependencies**:
   ```bash
   pip install pyyaml
   ```

3. **Create secrets file** (optional for local dev):
   ```bash
   # See ops/k8s/secrets/README.md for template
   touch ops/k8s/secrets/secrets.yaml
   ```

### Using Team Development Environments

#### Option 1: Python Script (Recommended)

**Professional K8s-like workflow - No `.env` files needed!**

```bash
# Navigate to your team's directory
cd team_dev_environments/<your-team>

# Run Python script (auto-loads k8s configmaps & secrets)
python run.py
```

**Benefits:**
- ✅ No `.env` files needed
- ✅ Mimics Kubernetes secret injection
- ✅ Loads from `ops/k8s/configmaps/` and `ops/k8s/secrets/`
- ✅ Professional microservices workflow
- ✅ Single source of truth for configuration

**What happens:**
1. Script reads k8s ConfigMaps from `ops/k8s/configmaps/*.yaml`
2. Script reads k8s Secrets from `ops/k8s/secrets/*.yaml`
3. Injects them into environment (mimics Kubernetes!)
4. Starts Docker containers with environment loaded

#### Option 2: Shell Scripts

```bash
# Navigate to your team's directory
cd team_dev_environments/<your-team>

# Build your services (first time only)
./build.sh

# Start your services
./start.sh        # Linux/Mac/WSL
.\start.ps1       # Windows PowerShell
```

### Team-Specific Services

| Team | Services | Command |
|------|----------|---------|
| **AI Team** | Cyrex, Ollama, MLflow, Jupyter | `cd team_dev_environments/ai-team && python run.py` |
| **ML Team** | Cyrex, MLflow, Analytics | `cd team_dev_environments/ml-team && python run.py` |
| **Backend Team** | All backend microservices + Frontend | `cd team_dev_environments/backend-team && python run.py` |
| **Frontend Team** | Frontend + API Gateway + Auth Service | `cd team_dev_environments/frontend-team && python run.py` |
| **Infrastructure Team** | PostgreSQL, Redis, InfluxDB, API Gateway, External Bridge | `cd team_dev_environments/infrastructure-team && python run.py` |
| **Platform Engineers** | Everything (full stack) | `cd team_dev_environments/platform-engineers && python run.py` |
| **QA Team** | Everything (for comprehensive testing) | `cd team_dev_environments/qa-team && python run.py` |

### Building Services

**When to build:**
- First time setup
- Dockerfile changes
- `package.json` or `requirements.txt` changes (dependencies)

**Build commands:**
```bash
# From your team's directory
cd team_dev_environments/<your-team>
./build.sh

# Or build manually
docker compose -f ../../docker-compose.dev.yml build <service-names>
```

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!

### Starting Services

```bash
# Recommended: Python script (loads k8s config)
cd team_dev_environments/<your-team>
python run.py

# Alternative: Shell script
./start.sh        # Linux/Mac/WSL
.\start.ps1       # Windows
```

### Stopping Services

```bash
# From your team's directory
cd team_dev_environments/<your-team>
./stop.sh

# Or from repository root
cd ../..
docker compose -f docker-compose.dev.yml down
```

### Viewing Logs

```bash
# All services
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f <service-name>

# Multiple services
docker compose -f docker-compose.dev.yml logs -f <service1> <service2>
```

### Accessing Services

After starting your team environment, services will be available at:

**Common ports:**
- Frontend: `http://localhost:5173`
- API Gateway: `http://localhost:5100`
- Auth Service: `http://localhost:5001`
- Core API: `http://localhost:5000`
- Cyrex: `http://localhost:8000`
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`
- pgAdmin: `http://localhost:5050`

**Check your team's README.md for specific URLs:**
```bash
cat team_dev_environments/<your-team>/README.md
```

### How It Works

All scripts use the main `docker-compose.dev.yml` file. They:
- **Build scripts**: Use `docker compose -f docker-compose.dev.yml build <services>`
- **Start scripts**: Use `docker compose -f docker-compose.dev.yml up -d <services>`

This means:
- ✅ Single source of truth (`docker-compose.dev.yml`)
- ✅ No duplicate configuration
- ✅ Easy to maintain
- ✅ Each team only builds/starts what they need

### Troubleshooting Team Environments

**Services not starting?**
```bash
# Check Docker is running
docker ps

# Check logs
docker compose -f docker-compose.dev.yml logs <service-name>

# Rebuild if needed
cd team_dev_environments/<your-team>
./build.sh
```

**Python script errors?**
```bash
# Install dependencies
pip install pyyaml

# Check k8s config files exist
ls ops/k8s/configmaps/
ls ops/k8s/secrets/
```

**Port conflicts?**
```bash
# Find what's using the port
lsof -i :5000
# Or
netstat -tulpn | grep :5000

# Change port in docker-compose.dev.yml or stop conflicting service
```

For detailed team-specific documentation, see:
- `team_dev_environments/README.md` - General overview
- `team_dev_environments/QUICK_START.md` - Quick start guide
- `team_dev_environments/<your-team>/README.md` - Team-specific guide

---

## Docker Setup

### ⭐ Recommended: Docker Engine in WSL2

**Why Docker Engine instead of Docker Desktop?**
- More reliable WSL2 integration
- Better performance
- Full control over Docker daemon
- No socket connection issues

### Automated Installation (Recommended)

```bash
# Navigate to project root
cd deepiri

# Run the automated installation script
./scripts/setup-docker-wsl2.sh

# After the script completes, restart WSL2:
# In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify installation
docker version
docker buildx version
docker ps
```

**What the script does:**
- ✅ Installs Docker Engine, Buildx, and Compose
- ✅ Verifies Docker's official GPG key fingerprint (security)
- ✅ Configures WSL2 for systemd
- ✅ Sets up DNS configuration
- ✅ Adds your user to the docker group
- ✅ Handles repository errors gracefully

### Manual Installation

See [QUICK-START-SCRIPTS.md](QUICK-START-SCRIPTS.md) for detailed manual installation steps.

### Verify Docker is Running

```bash
# Check Docker service status
sudo systemctl status docker

# Test Docker
docker run hello-world

# Verify Docker Compose
docker compose version
```

---

## Kubernetes Setup (Skaffold)

### 1. Install Minikube

```bash
# Download Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version

# Or use the setup script
./scripts/setup-minikube-wsl2.sh
```

### 2. Install kubectl

```bash
# Download and install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

**⚠️ Important:** kubectl is required for Skaffold to deploy to Kubernetes. If you get "kubectl: executable file not found in $PATH" errors, make sure kubectl is installed and in your PATH.

### 3. Install Skaffold

```bash
# Download Skaffold
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/skaffold
skaffold version

# Or install via package manager
# For Ubuntu/Debian:
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/skaffold
```

### 4. Start Minikube

```bash
# IMPORTANT: Make sure Docker is running first!
docker ps

# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

# Verify Minikube is running
minikube status
kubectl get nodes
```

**⚠️ Important Notes:**
- Minikube requires Docker to be running
- The `eval $(minikube docker-env)` command points Docker CLI to Minikube's daemon
- You need to run this in every new terminal session, or add it to your shell profile

---

## Environment Configuration

### 1. Copy Environment Files

```bash
# Navigate to project root
cd deepiri

# Copy example environment files
cp env.example .env

# Copy service-specific environment files
cp deepiri-core-api/env.example.api-server .env.deepiri-core-api 2>/dev/null || true
cp diri-cyrex/env.example.diri-cyrex .env.diri-cyrex 2>/dev/null || true
cp deepiri-web-frontend/env.example.frontend .env.deepiri-web-frontend 2>/dev/null || true
```

### 2. Configure Environment Variables

Edit `.env` file with your configuration:

```bash
# Required API Keys
OPENAI_API_KEY=your-openai-api-key-here
# OR
ANTHROPIC_API_KEY=your-anthropic-api-key-here

# Database Configuration
MONGO_ROOT_PASSWORD=your-secure-password
MONGO_DATABASE=deepiri

# Redis Configuration
REDIS_PASSWORD=your-redis-password

# Firebase (Optional)
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=your-firebase-private-key
FIREBASE_CLIENT_EMAIL=your-firebase-client-email

# Frontend Environment Variables
VITE_API_URL=http://localhost:5000
VITE_FIREBASE_API_KEY=your-firebase-api-key
VITE_FIREBASE_AUTH_DOMAIN=your-firebase-auth-domain
VITE_FIREBASE_PROJECT_ID=your-firebase-project-id
```

**📝 Note:** For detailed environment variable reference, see [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)

### 3. Firebase Configuration (Optional)

If using Firebase, you have two options:

**Option A: JSON File (for local development)**
- Place Firebase service account JSON files in:
  - `deepiri-core-api/config/tripblip-mag-firebase-adminsdk-*.json`
  - `deepiri-core-api/src/config/tripblip-firebase-adminsdk-*.json`

**Option B: Environment Variables (recommended for Docker/K8s)**
- Set `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`, etc. in `.env`
- The code will automatically use environment variables if JSON files are missing

---

## Building All Services

### ⭐ Primary Method: Build with Skaffold

Skaffold will build all services automatically:

```bash
# Navigate to project root
cd deepiri

# Make sure Minikube is running and Docker is configured
minikube status
eval $(minikube docker-env)

# Auto-detect GPU and build (recommended)
./scripts/skaffold-build.sh

# Or specify profile manually
./scripts/skaffold-build.sh cpu    # For CPU-only builds (Intel Iris Xe, etc.)
./scripts/skaffold-build.sh gpu    # For NVIDIA GPU builds
```

**What gets built:**
- ✅ `deepiri-core-api` - Main API server
- ✅ `deepiri-cyrex` - AI/ML service
- ✅ `deepiri-frontend` - React frontend
- ✅ `deepiri-api-gateway` - API Gateway
- ✅ `deepiri-auth-service` - Authentication service
- ✅ `deepiri-task-orchestrator` - Task orchestration
- ✅ `deepiri-challenge-service` - Challenge service
- ✅ `deepiri-engagement-service` - Engagement service
- ✅ `deepiri-platform-analytics-service` - Analytics service
- ✅ `deepiri-external-bridge-service` - External integrations
- ✅ `deepiri-notification-service` - Notifications
- ✅ `deepiri-realtime-gateway` - WebSocket gateway

### Manual Build (Alternative)

If you prefer to build manually:

```bash
# Build all services with Skaffold
skaffold build --profile=cpu

# Or for GPU
skaffold build --profile=gpu
```

### Build Individual Services

```bash
# Build specific service
docker build -t deepiri-core-api ./deepiri-core-api
docker build -t deepiri-frontend ./deepiri-web-frontend
docker build -t deepiri-cyrex ./diri-cyrex
```

---

## Running the Application

### ⭐ Primary Method: Run with Skaffold

**Start all services:**

```bash
# Navigate to project root
cd deepiri

# Ensure Minikube is running
minikube status || minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker for Minikube
eval $(minikube docker-env)

# Start all services with Skaffold
skaffold dev --profile=cpu

# Or use the start script
./scripts/start-skaffold-dev.sh cpu
```

**What happens:**
- ✅ Builds all Docker images
- ✅ Deploys all services to Minikube
- ✅ Sets up service networking
- ✅ Watches for code changes and rebuilds
- ✅ Streams logs from all services

### Access the Application

```bash
# Get Minikube IP
minikube ip

# Get service URLs
minikube service list

# Access frontend
minikube service deepiri-frontend

# Access API
minikube service deepiri-core-api

# Or use port forwarding
kubectl port-forward service/deepiri-frontend 3000:80
kubectl port-forward service/deepiri-core-api 5000:5000
```

### Alternative: Docker Compose

If you prefer Docker Compose (simpler, but not Kubernetes):

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Verification

### 1. Check All Services are Running

```bash
# Check Kubernetes pods
kubectl get pods

# Check services
kubectl get services

# Check deployments
kubectl get deployments

# View logs
kubectl logs -f deployment/deepiri-core-api
kubectl logs -f deployment/deepiri-frontend
```

### 2. Test API Endpoints

```bash
# Health check
curl http://localhost:5000/api/health

# Or via Minikube
curl $(minikube service deepiri-core-api --url)/api/health
```

### 3. Access Frontend

Open your browser and navigate to:
- **Frontend:** http://localhost:3000 (or Minikube service URL)
- **API:** http://localhost:5000 (or Minikube service URL)

### 4. Verify Database Connection

```bash
# Check MongoDB connection
kubectl exec -it deployment/deepiri-core-api -- npm run test:db

# Or check logs for connection messages
kubectl logs deployment/deepiri-core-api | grep -i mongo
```

---

## Troubleshooting

### Common Issues

#### 1. Docker Daemon Not Running

```bash
# Check Docker status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker
```

#### 2. Minikube Won't Start

```bash
# Check Docker is running
docker ps

# Delete and recreate Minikube
minikube delete
minikube start --driver=docker --cpus=4 --memory=8192
```

#### 3. Build Failures

```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
skaffold build --profile=cpu --no-cache

# Check build logs
skaffold build --profile=cpu --verbosity=debug
```

#### 4. Port Already in Use

```bash
# Find process using port
lsof -i :5000
# Or
netstat -tulpn | grep :5000

# Kill process or change port in configuration
```

#### 5. TypeScript Build Errors

If you see TypeScript errors during build:
- Check Node.js version (should be 20.x+)
- Verify `tsconfig.json` settings
- Some type errors are warnings and won't block the build

#### 6. GPU Detection Issues

```bash
# Check GPU
nvidia-smi

# Force CPU profile
./scripts/skaffold-build.sh cpu

# For Intel Iris Xe Graphics, always use CPU profile
```

### Getting Help

- **Documentation:** See [docs/](docs/) for team-specific guides
- **Troubleshooting Guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Quick Start:** [QUICK-START-SCRIPTS.md](QUICK-START-SCRIPTS.md)
- **Skaffold Guide:** [SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)

---

## Next Steps

After completing setup:

1. **Read Team-Specific Guides:**
   - [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md)
   - [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md)
   - [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)
   - [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)

2. **Explore the Codebase:**
   - `deepiri-core-api/` - Main API server
   - `deepiri-web-frontend/` - React frontend
   - `diri-cyrex/` - AI/ML service
   - `platform-services/backend/` - Microservices

3. **Start Developing:**
   - Make code changes
   - Skaffold will automatically rebuild and redeploy
   - Check logs: `kubectl logs -f deployment/<service-name>`

---

## Summary

✅ **Prerequisites installed** (Docker, Minikube, Skaffold, Node.js, Python)  
✅ **Git hooks configured** (Branch protection enabled)  
✅ **Submodules set up** (Team-specific submodules pulled)  
✅ **Team dev environment ready** (Services built and configured)  
✅ **Docker configured** (Docker Engine in WSL2)  
✅ **Minikube running** (Kubernetes cluster ready)  
✅ **Environment configured** (.env files or k8s config set up)  
✅ **All services built** (Docker images created)  
✅ **Application running** (All services deployed)  
✅ **Verified** (Health checks passing, frontend accessible)

**You're all set! 🎉**

### Next Steps

1. **Read Team-Specific Guides:**
   - Git Hooks: See [Git Hooks Setup](#git-hooks-setup)
   - Submodules: See [Submodule Management](#submodule-management)
   - Dev Environments: See [Team Development Environments](#team-development-environments)
   - Team Onboarding: See [docs/](docs/) for team-specific guides

2. **Explore the Codebase:**
   - `deepiri-core-api/` - Main API server
   - `deepiri-web-frontend/` - React frontend
   - `diri-cyrex/` - AI/ML service
   - `platform-services/backend/` - Microservices
   - `team_submodule_commands/` - Submodule management
   - `team_dev_environments/` - Team dev environments

3. **Start Developing:**
   - Use your team's dev environment: `cd team_dev_environments/<your-team> && python run.py`
   - Make code changes (hot reload enabled)
   - Check logs: `docker compose -f docker-compose.dev.yml logs -f <service-name>`
   - Create feature branches: `git checkout -b firstname_lastname/feature/feature-name`

For detailed information on specific services or development workflows, see the team-specific onboarding guides in [docs/](docs/).

