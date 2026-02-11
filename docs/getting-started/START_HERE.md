# 🚀 START HERE - Deepiri Platform Setup Guide

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

```bash
git clone <your-repo-url>
cd deepiri-platform
```

### 2. Git Hooks (Automatic!)

**✅ Git hooks are automatically configured when you clone the repository!**

The hooks protect the `main` and `dev` branches from accidental pushes. You'll need to use Pull Requests instead.

**If hooks aren't working** (e.g., existing clone), run:
```bash
./setup-hooks.sh
```

**Why?** See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for details.

---

## 👥 Step 3: Follow Your Team's Path

After setting up Git hooks, follow your team-specific path:

### 🤖 AI Team
1. **Onboarding:** [docs/onboarding/AI_TEAM_ONBOARDING.md](docs/onboarding/AI_TEAM_ONBOARDING.md)
2. **Dev Environment:** [team_dev_environments/ai-team/README.md](team_dev_environments/ai-team/README.md)
3. **Submodules:** [team_submodule_commands/ai-team/AI_TEAM.md](team_submodule_commands/ai-team/AI_TEAM.md)

### 🧠 ML Team
1. **ML Guide:** [docs/development/ML_ENGINEER_COMPLETE_GUIDE.md](docs/development/ML_ENGINEER_COMPLETE_GUIDE.md)
2. **MLOps:** [docs/onboarding/MLOPS_TEAM_ONBOARDING.md](docs/onboarding/MLOPS_TEAM_ONBOARDING.md)
3. **Dev Environment:** [team_dev_environments/ml-team/README.md](team_dev_environments/ml-team/README.md)
4. **Submodules:** [team_submodule_commands/ml-team/ML_TEAM.md](team_submodule_commands/ml-team/ML_TEAM.md)

### ⚙️ Backend Team
1. **Onboarding:** [docs/onboarding/BACKEND_TEAM_ONBOARDING.md](docs/onboarding/BACKEND_TEAM_ONBOARDING.md)
2. **Microservices:** [docs/architecture/MICROSERVICES_SETUP.md](docs/architecture/MICROSERVICES_SETUP.md)
3. **Dev Environment:** [team_dev_environments/backend-team/README.md](team_dev_environments/backend-team/README.md)
4. **Submodules:** [team_submodule_commands/backend-team/BACKEND_TEAM.md](team_submodule_commands/backend-team/BACKEND_TEAM.md)

### 🎨 Frontend Team
1. **Onboarding:** [docs/onboarding/FRONTEND_TEAM_ONBOARDING.md](docs/onboarding/FRONTEND_TEAM_ONBOARDING.md)
2. **Dev Environment:** [team_dev_environments/frontend-team/README.md](team_dev_environments/frontend-team/README.md)
3. **Submodules:** [team_submodule_commands/frontend-team/FRONTEND_TEAM.md](team_submodule_commands/frontend-team/FRONTEND_TEAM.md)

### 🏗️ Infrastructure Team
1. **Onboarding:** [docs/onboarding/PLATFORM_TEAM_ONBOARDING.md](docs/onboarding/PLATFORM_TEAM_ONBOARDING.md)
2. **Skaffold:** [docs/infrastructure/SKAFFOLD_SETUP.md](docs/infrastructure/SKAFFOLD_SETUP.md)
3. **Dev Environment:** [team_dev_environments/infrastructure-team/README.md](team_dev_environments/infrastructure-team/README.md)
4. **Submodules:** [team_submodule_commands/infrastructure-team/INFRASTRUCTURE_TEAM.md](team_submodule_commands/infrastructure-team/INFRASTRUCTURE_TEAM.md)

### 🔧 Platform Engineers
1. **Onboarding:** [docs/onboarding/PLATFORM_TEAM_ONBOARDING.md](docs/onboarding/PLATFORM_TEAM_ONBOARDING.md)
2. **Dev Environment:** [team_dev_environments/platform-engineers/README.md](team_dev_environments/platform-engineers/README.md)
3. **Submodules:** [team_submodule_commands/platform-engineers/PLATFORM_ENGINEERS.md](team_submodule_commands/platform-engineers/PLATFORM_ENGINEERS.md)

### 🧪 QA Team
1. **Onboarding:** [docs/onboarding/SECURITY_QA_TEAM_ONBOARDING.md](docs/onboarding/SECURITY_QA_TEAM_ONBOARDING.md)
2. **Dev Environment:** [team_dev_environments/qa-team/README.md](team_dev_environments/qa-team/README.md)
3. **Submodules:** [team_submodule_commands/qa-team/QA_TEAM.md](team_submodule_commands/qa-team/QA_TEAM.md)

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

4. **Open a Pull Request** into `staging` (NOT `main` or `dev`)

**⚠️ Remember:** Direct pushes to `main` and `dev` are blocked. You must use Pull Requests.

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
- [ ] Verified Git hooks are working (try pushing to main/dev - should be blocked)
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

