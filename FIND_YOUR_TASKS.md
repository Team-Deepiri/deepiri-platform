# Find Your Tasks - Team Roles & Responsibilities

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
2. [team_dev_environments/ai-team/README.md](team_dev_environments/ai-team/README.md) - Your dev environment
3. [team_submodule_commands/ai-team/AI_TEAM.md](team_submodule_commands/ai-team/AI_TEAM.md) - Submodule workflow

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
3. [team_dev_environments/ml-team/README.md](team_dev_environments/ml-team/README.md) - Your dev environment
4. [team_submodule_commands/ml-team/ML_TEAM.md](team_submodule_commands/ml-team/ML_TEAM.md) - Submodule workflow

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
3. [team_dev_environments/backend-team/README.md](team_dev_environments/backend-team/README.md) - Your dev environment
4. [team_submodule_commands/backend-team/BACKEND_TEAM.md](team_submodule_commands/backend-team/BACKEND_TEAM.md) - Submodule workflow

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
2. [team_dev_environments/frontend-team/README.md](team_dev_environments/frontend-team/README.md) - Your dev environment
3. [team_submodule_commands/frontend-team/FRONTEND_TEAM.md](team_submodule_commands/frontend-team/FRONTEND_TEAM.md) - Submodule workflow

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
- All infrastructure (MongoDB, Redis, InfluxDB)
- API Gateway
- All microservices (for monitoring)

**📚 Your path:**
1. [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md) - Platform guide
2. [docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md) - Skaffold/Kubernetes setup
3. [team_dev_environments/infrastructure-team/README.md](team_dev_environments/infrastructure-team/README.md) - Your dev environment
4. [team_submodule_commands/infrastructure-team/INFRASTRUCTURE_TEAM.md](team_submodule_commands/infrastructure-team/INFRASTRUCTURE_TEAM.md) - Submodule workflow

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
2. [team_dev_environments/platform-engineers/README.md](team_dev_environments/platform-engineers/README.md) - Your dev environment
3. [team_submodule_commands/platform-engineers/PLATFORM_ENGINEERS.md](team_submodule_commands/platform-engineers/PLATFORM_ENGINEERS.md) - Submodule workflow

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
2. [team_dev_environments/qa-team/README.md](team_dev_environments/qa-team/README.md) - Your dev environment
3. [team_submodule_commands/qa-team/QA_TEAM.md](team_submodule_commands/qa-team/QA_TEAM.md) - Submodule workflow

---

## 🚀 Quick Start for Any Team

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd deepiri-platform
   ```

2. **Set up Git hooks (REQUIRED - protects main and dev branches):**
   ```bash
   ./setup-hooks.sh
   ```

3. **Follow your team's onboarding guide** (see links above)

4. **Set up your development environment:**
   - Navigate to `team_dev_environments/<your-team>/`
   - Follow the README.md

5. **Set up submodules:**
   - Navigate to `team_submodule_commands/<your-team>/`
   - Follow the team-specific guide

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

