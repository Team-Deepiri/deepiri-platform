# Git Submodule Commands - Team Documentation

This directory contains comprehensive documentation for working with Git submodules in the Deepiri project, organized by team.

## 📚 Directory Structure

```
team_submodule_commands/
├── README.md                          # This file - Overview
├── SUBMODULE_COMMANDS.md              # Complete submodule migration and management guide
│
├── ai-team/
│   ├── AI_TEAM.md                     # AI Team specific commands
│   └── pull_submodules.sh             # Script to pull AI submodules
│
├── ml-team/
│   ├── ML_TEAM.md                     # ML Team specific commands
│   └── pull_submodules.sh             # Script to pull ML submodules
│
├── infrastructure-team/
│   ├── INFRASTRUCTURE_TEAM.md         # Infrastructure Team specific commands
│   └── pull_submodules.sh             # Script to pull infrastructure submodules
│
├── backend-team/
│   ├── BACKEND_TEAM.md                # Backend Team specific commands
│   └── pull_submodules.sh             # Script to pull backend submodules
│
├── frontend-team/
│   ├── FRONTEND_TEAM.md               # Frontend Team specific commands
│   └── pull_submodules.sh             # Script to pull frontend submodules
│
├── qa-team/
│   ├── QA_TEAM.md                     # QA Team specific commands
│   └── pull_submodules.sh             # Script to pull all submodules (QA needs everything)
│
└── platform-engineers/
    ├── PLATFORM_ENGINEERS.md          # Platform Engineers specific commands
    └── pull_submodules.sh             # Script to pull all submodules (Platform manages everything)
```

## 🚀 Quick Start

### First Time Setup

```bash
# Clone the main repository with all submodules
git clone --recursive https://github.com/Team-Deepiri/deepiri.git
cd deepiri-platform

# Set up Git hooks (REQUIRED - protects main and dev branches)
./setup-hooks.sh
```

### After Pulling Main Repo

```bash
# Update main repository
git pull origin main

# Run your team's pull script
./team_submodule_commands/YOUR_TEAM/pull_submodules.sh
```

## 📦 Available Submodules

| Submodule | Path | Team(s) |
|-----------|------|---------|
| **diri-cyrex** | `diri-cyrex` | AI, ML |
| **deepiri-core-api** | `deepiri-core-api` | Backend |
| **deepiri-web-frontend** | `deepiri-web-frontend` | Frontend, Backend |
| **deepiri-api-gateway** | `platform-services/backend/deepiri-api-gateway` | Infrastructure, Backend, Platform |
| **deepiri-auth-service** | `platform-services/backend/deepiri-auth-service` | Backend, Platform |
| **deepiri-external-bridge-service** | `platform-services/backend/deepiri-external-bridge-service` | Infrastructure, Backend, Platform |

## 🌿 Branch Naming Convention

**⚠️ REQUIRED FOR ALL TEAMS:**

All feature and bug fix branches must follow this naming convention:

- **Features**: `firstname_lastname/feature/feature_name`
- **Bug Fixes**: `firstname_lastname/bug/bug_fix_name`

**Examples:**
- `john_doe/feature/add-user-authentication`
- `jane_smith/feature/improve-api-performance`
- `bob_jones/bug/fix-database-connection-pool`
- `alice_williams/bug/fix-jwt-expiration`

**Why?**
- Easy to identify who owns the branch
- Clear separation between features and bug fixes
- Better code review organization
- Prevents branch name conflicts

## 📋 Team-Specific Guides

### AI Team
- **Directory**: `ai-team/`
- **Guide**: [AI_TEAM.md](./ai-team/AI_TEAM.md)
- **Pull Script**: `./team_submodule_commands/ai-team/pull_submodules.sh`
- **Required Submodules**: `diri-cyrex`

### ML Team
- **Directory**: `ml-team/`
- **Guide**: [ML_TEAM.md](./ml-team/ML_TEAM.md)
- **Pull Script**: `./team_submodule_commands/ml-team/pull_submodules.sh`
- **Required Submodules**: `diri-cyrex`

### Infrastructure Team
- **Directory**: `infrastructure-team/`
- **Guide**: [INFRASTRUCTURE_TEAM.md](./infrastructure-team/INFRASTRUCTURE_TEAM.md)
- **Pull Script**: `./team_submodule_commands/infrastructure-team/pull_submodules.sh`
- **Required Submodules**: `deepiri-api-gateway`, `deepiri-external-bridge-service`

### Backend Team
- **Directory**: `backend-team/`
- **Guide**: [BACKEND_TEAM.md](./backend-team/BACKEND_TEAM.md)
- **Pull Script**: `./team_submodule_commands/backend-team/pull_submodules.sh`
- **Required Submodules**: `deepiri-core-api`, `deepiri-api-gateway`, `deepiri-auth-service`, `deepiri-external-bridge-service`, `deepiri-web-frontend`

### Frontend Team
- **Directory**: `frontend-team/`
- **Guide**: [FRONTEND_TEAM.md](./frontend-team/FRONTEND_TEAM.md)
- **Pull Script**: `./team_submodule_commands/frontend-team/pull_submodules.sh`
- **Required Submodules**: `deepiri-web-frontend`

### QA Team
- **Directory**: `qa-team/`
- **Guide**: [QA_TEAM.md](./qa-team/QA_TEAM.md)
- **Pull Script**: `./team_submodule_commands/qa-team/pull_submodules.sh`
- **Required Submodules**: **ALL** (for comprehensive testing)

### Platform Engineers
- **Directory**: `platform-engineers/`
- **Guide**: [PLATFORM_ENGINEERS.md](./platform-engineers/PLATFORM_ENGINEERS.md)
- **Pull Script**: `./team_submodule_commands/platform-engineers/pull_submodules.sh`
- **Required Submodules**: **ALL** (for platform management)

## 🔧 Common Commands

### Check Submodule Status
```bash
git submodule status
```

### Update All Submodules
```bash
git submodule update --remote --recursive
```

### Update Specific Submodule
```bash
git submodule update --remote <submodule-path>
```

### Work Inside a Submodule
```bash
cd <submodule-path>
# Create feature branch with your name
git checkout -b firstname_lastname/feature/your_feature_name
# Make your changes
git add .
git commit -m "feat: your change"
git push origin firstname_lastname/feature/your_feature_name
cd ..
git add <submodule-path>
git commit -m "chore: update <submodule-name>"
git push origin main
```

## 📖 Full Documentation

For complete submodule migration, management, and troubleshooting, see [SUBMODULE_COMMANDS.md](./SUBMODULE_COMMANDS.md).

---

**Last Updated**: 2024  
**Maintained By**: Platform Engineering Team
