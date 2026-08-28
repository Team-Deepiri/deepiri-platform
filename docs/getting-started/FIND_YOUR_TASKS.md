# Find Your Tasks - Team Roles & Responsibilities

> **Repo split:** Team catalogs and `./setup-deepiri-dev.sh` live in **[deepiri-control-plane](https://github.com/Team-Deepiri/deepiri-control-plane)**. This cloud repo keeps copies under `teams/` for reference; use `teams/cloud-portal.yml` here for VPS deploy.

**🎯 Start here to find your team and understand your role in the Deepiri platform.**

---
## 👥 Choose Your Team

### 🤖 AI Team
**What you do:**
- Build AI/ML models for challenge generation
- Develop task understanding algorithms
- Create RL models for personalization
- Work on multimodal AI integration

**Your code:**
- `diri-cyrex/` - Main AI service (Python/FastAPI)
- `platform-services/backend/deepiri-challenge-service/` - Challenge integration

**Your services:**
- Cyrex AI Service (Port 8000)
- Jupyter (Port 8888)
- MLflow (Port 5500)
- Challenge Service (Port 5007)

**📚 Your path:**
1. [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md) - Complete onboarding guide
2. **Catalog:** `teams/ai-team.yml` — `./setup-deepiri-dev.sh pull|build|start ai-team`

---

### 🧠 ML Team
**What you do:**
- Train and optimize ML models
- Feature engineering and data analysis
- Model versioning and tracking
- Analytics and predictions

**Your code:**
- `diri-cyrex/app/services/` - ML model implementations
- `diri-cyrex/train/` - Training pipelines
- `platform-services/backend/deepiri-platform-analytics-service/` - Analytics

**Your services:**
- Cyrex AI Service (Port 8000)
- Jupyter (Port 8888)
- MLflow (Port 5500)
- Analytics Service (Port 5004)

**📚 Your path:**
1. [docs/ML_ENGINEER_COMPLETE_GUIDE.md](docs/ML_ENGINEER_COMPLETE_GUIDE.md) - Complete ML guide
2. [docs/MLOPS_TEAM_ONBOARDING.md](docs/MLOPS_TEAM_ONBOARDING.md) - MLOps workflow
3. **Catalog:** `teams/ml-team.yml` — `./setup-deepiri-dev.sh pull|build|start ml-team`

---

### ⚙️ Backend Team
**What you do:**
- Build microservices architecture
- API development and integration
- Service-to-service communication
- Database design and optimization

**Your code:**
- `platform-services/backend/*/` - All microservices
- `deepiri-core-api/` - Legacy monolith (being migrated)

**Your services:**
- API Gateway (Port 5000)
- Auth Service (Port 5001)
- Task Orchestrator (Port 5002)
- Engagement Service (Port 5003)
- Analytics Service (Port 5004)
- Notification Service (Port 5005)
- External Bridge (Port 5006)
- Challenge Service (Port 5007)
- Realtime Gateway (Port 5008)

**📚 Your path:**
1. [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md) - Complete onboarding guide
2. [docs/MICROSERVICES_SETUP.md](docs/MICROSERVICES_SETUP.md) - Microservices architecture
3. **Catalog:** `teams/backend-team.yml` — `./setup-deepiri-dev.sh pull|build|start backend-team`

---

### 🎨 Frontend Team
**What you do:**
- Build React UI components
- API integration and state management
- WebSocket real-time features
- User experience and design

**Your code:**
- `deepiri-web-frontend/` - React frontend (Vite)

**Your services:**
- Frontend (Port 5173)
- Realtime Gateway (Port 5008) - WebSocket
- All backend services (for API calls)

**📚 Your path:**
1. [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md) - Complete onboarding guide
2. **Catalog:** `teams/frontend-team.yml` — `./setup-deepiri-dev.sh pull|build|start frontend-team`

---

### 🏗️ Infrastructure Team
**What you do:**
- Kubernetes orchestration
- Docker and container management
- Database setup and monitoring
- CI/CD pipelines
- Platform infrastructure

**Your code:**
- `ops/k8s/` - Kubernetes manifests
- `docker-compose.*.yml` - Service orchestration
- `skaffold/*.yaml` - Build and deployment

**Your services:**
- API Gateway
- All microservices (for monitoring)

**📚 Your path:**
1. [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md) - Platform guide
2. [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md) - Skaffold/Kubernetes setup
3. **Catalog:** `teams/infrastructure-team.yml` — `./setup-deepiri-dev.sh pull|build|start infrastructure-team`

---

### 🔧 Platform Engineers
**What you do:**
- Platform standards and tooling
- Cross-team coordination
- Platform infrastructure management
- CI/CD and automation

**Your code:**
- Everything (platform-wide responsibility)
- Platform tooling and standards

**Your services:**
- All services (for platform development)

**📚 Your path:**
1. [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md) - Complete platform guide
2. **Catalog:** `teams/platform-engineers.yml` — `./setup-deepiri-dev.sh pull|build|start platform-engineers`

---

### 🧪 QA Team
**What you do:**
- End-to-end testing
- Integration testing
- Performance testing
- Security testing

**Your code:**
- All codebases (comprehensive testing)

**Your services:**
- All services (for testing)

**📚 Your path:**
1. [docs/SECURITY_QA_TEAM_ONBOARDING.md](docs/SECURITY_QA_TEAM_ONBOARDING.md) - Complete QA guide
2. **Catalog:** `teams/qa-team.yml` — `./setup-deepiri-dev.sh pull|build|start qa-team`

---

## 🚀 Quick Start for Any Team

**Cloud portal deploy** → clone **deepiri-platform** and use `docker compose -f docker-compose.yml up -d`.

**Local dev (Cyrex, LIS, speech, team catalogs)** → clone **deepiri-control-plane**:

1. **Clone the repository:**
   ```bash
   git clone git@github.com:Team-Deepiri/deepiri-control-plane.git
   cd deepiri-control-plane
   ```

2. **Set up Git hooks (REQUIRED - protects main/master and branches containing team-dev):**
   ```bash
   ./setup-hooks.sh
   # Also synced for team submodules on: ./setup-deepiri-dev.sh pull <your-team>
   ```

3. **Follow your team's onboarding guide** (see links above)

4. **Set up submodules, build, and start your team's services:**
   ```bash
   ./setup-deepiri-dev.sh pull <your-team>
   ./setup-deepiri-dev.sh build <your-team>
   ./setup-deepiri-dev.sh start <your-team>
   ```
   Team catalogs live in `teams/<your-team>.yml`.

---

## 📋 Service Communication

For details on which services your team needs to run, see:
- [SERVICE_COMMUNICATION_AND_TEAMS.md](SERVICE_COMMUNICATION_AND_TEAMS.md) - Complete service architecture

---

## 🔗 Additional Resources

- [START_HERE.md](START_HERE.md) - Complete getting started guide
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) - Branch protection rules
- [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) - All documentation

---

**Last Updated:** 2024  
**Maintained by:** Platform Team

