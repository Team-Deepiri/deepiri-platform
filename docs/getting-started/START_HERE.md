# 🚀 START HERE - Deepiri Platform Setup Guide

> **Repo split (2026-08-26):** This repo (**deepiri-platform**) is the **cloud VPS portal** only.  
> For Cyrex, LIS, speech, Kafka, and team dev onboarding → **[deepiri-control-plane](https://github.com/Team-Deepiri/deepiri-control-plane)** (`docker-compose.dev.yml`, `setup-deepiri-dev.sh`).

**Welcome to Deepiri! This is your complete getting started guide.**

---

## 📍 Step 1: Find Your Team

**Not sure which team you're on?** → [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)

This will help you identify:
- Your role and responsibilities
- Which services you work with
- Your team-specific documentation path

---

## 🔧 Step 2: Initial Repository Setup

### 1. Clone the Repository

**Cloud portal (this repo):**
```bash
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform
```

**Full local dev stack (AI/backend teams):**
```bash
git clone git@github.com:Team-Deepiri/deepiri-control-plane.git
cd deepiri-control-plane
bash setup-deepiri-dev.sh
```

### 2. Git Hooks (Automatic!)

**✅ Git hooks are automatically configured when you clone the repository!**

The hooks protect `main`, `master`, and branches containing `team-dev` from accidental pushes. Use Pull Requests for protected branches.

**If hooks aren't working** (e.g., existing clone), run:
```bash
./setup-hooks.sh
# Team submodule hooks are also synced on: ./setup-deepiri-dev.sh pull <team>
```

**Why?** See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for details.

---

## 👥 Step 3: Follow Your Team's Path

After setting up Git hooks, follow your team-specific path:

All teams now use the single `./setup-deepiri-dev.sh` script with their team catalog in `teams/<team>.yml` (see [ENVIRONMENT_SETUP_WITH_SCRIPT.md](ENVIRONMENT_SETUP_WITH_SCRIPT.md) for full usage). Onboarding docs below cover team-specific context; the `team_dev_environments/` and `team_submodule_commands/` folders they may still reference have been replaced by this script.

### 🤖 AI Team
1. **Onboarding:** [docs/onboarding/AI_TEAM_ONBOARDING.md](docs/onboarding/AI_TEAM_ONBOARDING.md)
2. **Catalog:** `teams/ai-team.yml` — `./setup-deepiri-dev.sh pull|build|start ai-team`

### 🧠 ML Team
1. **ML Guide:** [docs/development/ML_ENGINEER_COMPLETE_GUIDE.md](docs/development/ML_ENGINEER_COMPLETE_GUIDE.md)
2. **MLOps:** [docs/onboarding/MLOPS_TEAM_ONBOARDING.md](docs/onboarding/MLOPS_TEAM_ONBOARDING.md)
3. **Catalog:** `teams/ml-team.yml` — `./setup-deepiri-dev.sh pull|build|start ml-team`

### ⚙️ Backend Team
1. **Onboarding:** [docs/onboarding/BACKEND_TEAM_ONBOARDING.md](docs/onboarding/BACKEND_TEAM_ONBOARDING.md)
2. **Microservices:** [docs/architecture/MICROSERVICES_SETUP.md](docs/architecture/MICROSERVICES_SETUP.md)
3. **Catalog:** `teams/backend-team.yml` — `./setup-deepiri-dev.sh pull|build|start backend-team`

### 🎨 Frontend Team
1. **Onboarding:** [docs/onboarding/FRONTEND_TEAM_ONBOARDING.md](docs/onboarding/FRONTEND_TEAM_ONBOARDING.md)
2. **Catalog:** `teams/frontend-team.yml` — `./setup-deepiri-dev.sh pull|build|start frontend-team`

### 🏗️ Infrastructure Team
1. **Onboarding:** [docs/onboarding/PLATFORM_TEAM_ONBOARDING.md](docs/onboarding/PLATFORM_TEAM_ONBOARDING.md)
2. **Skaffold:** [docs/infrastructure/SKAFFOLD_SETUP.md](docs/infrastructure/SKAFFOLD_SETUP.md)
3. **Catalog:** `teams/infrastructure-team.yml` — `./setup-deepiri-dev.sh pull|build|start infrastructure-team`

### 🔧 Platform Engineers
1. **Onboarding:** [docs/onboarding/PLATFORM_TEAM_ONBOARDING.md](docs/onboarding/PLATFORM_TEAM_ONBOARDING.md)
2. **Catalog:** `teams/platform-engineers.yml` — `./setup-deepiri-dev.sh pull|build|start platform-engineers`

### 🧪 QA Team
1. **Onboarding:** [docs/onboarding/SECURITY_QA_TEAM_ONBOARDING.md](docs/onboarding/SECURITY_QA_TEAM_ONBOARDING.md)
2. **Catalog:** `teams/qa-team.yml` — `./setup-deepiri-dev.sh pull|build|start qa-team`

---

## 📚 Step 4: Essential Documentation

### For All Teams

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines and workflow
- **[BRANCH_PROTECTION.md](BRANCH_PROTECTION.md)** - Branch protection rules
- **[docs/architecture/SERVICE_COMMUNICATION_AND_TEAMS.md](docs/architecture/SERVICE_COMMUNICATION_AND_TEAMS.md)** - Service architecture
- **[docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)** - Complete documentation index

### Build & Development

- **[HOW_TO_BUILD.md](HOW_TO_BUILD.md)** - Build guide
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Detailed setup walkthrough
- **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** - Environment configuration

---

## 🎯 Quick Reference

### Git Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes and commit:**
   ```bash
   git add .
   git commit -m "feat: your feature description"
   ```

3. **Push your branch:**
   ```bash
   git push -u origin feature/your-feature-name
   ```

4. **Open a Pull Request** into `dev` (or `staging` if your team flow uses it)

**⚠️ Remember:** Direct pushes to `main`, `master`, and branches containing `team-dev` are blocked.

### Common Commands

```bash
# Build all services
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell

# Start all services
docker compose -f docker-compose.dev.yml up -d

# Start only your team's services
docker compose -f docker-compose.<team>-team.yml up -d

# View logs
docker compose -f docker-compose.dev.yml logs -f
```

---

## 🆘 Need Help?

1. **Check your team's onboarding guide** (see Step 3 above)
2. **Review [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)** for role-specific info
3. **See [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)** for all documentation
4. **Check [docs/troubleshooting/TROUBLESHOOTING.md](docs/troubleshooting/TROUBLESHOOTING.md)** for common issues

---

## ✅ Setup Checklist

- [ ] Cloned the repository (Git hooks automatically configured!)
- [ ] Verified Git hooks are working (try pushing to `main` or `my-team-dev` - should be blocked)
- [ ] Read [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md) to identify your team
- [ ] Followed your team's onboarding guide
- [ ] Set up your development environment
- [ ] Set up your team's submodules
- [ ] Read [CONTRIBUTING.md](CONTRIBUTING.md) for workflow guidelines

---

**You're ready to start contributing! 🎉**

---

**Last Updated:** 2024  
**Maintained by:** Platform Team

