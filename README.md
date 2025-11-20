# Deepiri - AI-Powered Digital Productivity Playground

Welcome to Deepiri, your AI-powered digital productivity playground that gamifies your tasks, study material, coding projects, and creative work into engaging mini-games, challenges, and interactive experiences.

## 🚀 Quick Start

**New to Deepiri? Start here!**

1. **Prerequisites**
   - Docker and Docker Compose installed
   - Git
   - (Optional) Minikube + Skaffold for Kubernetes development

2. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd deepiri
   cp env.example .env
   # Edit .env with your API keys
   ```

3. **Start Everything**

   **⭐ PRIMARY: Kubernetes with Skaffold (Recommended)**
   ```bash
   # Setup Minikube (first time only)
   minikube start --driver=docker --cpus=4 --memory=8192
   eval $(minikube docker-env)
   
   # Or use setup script
   ./scripts/setup-minikube-wsl2.sh      # Linux/WSL2
   .\scripts\setup-minikube-wsl2.ps1     # Windows PowerShell
   
   # Start with Skaffold (uses skaffold-local.yaml)
   ./scripts/start-skaffold-dev.sh        # Linux/WSL2
   .\scripts\start-skaffold-dev.ps1      # Windows PowerShell
   
   # Or directly
   skaffold dev -f skaffold-local.yaml --port-forward
   ```

   **Alternative: Docker Compose**
   ```bash
   # Normal start (uses existing images - fast!)
   docker compose -f docker-compose.dev.yml up -d
   
   # First time or after code changes? Rebuild:
   ./rebuild.sh        # Linux/Mac
   .\rebuild.ps1       # Windows PowerShell
   ```

4. **Access Services**
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:5000
   - Python Agent: http://localhost:8000
   - MLflow: http://localhost:5500
   - API Docs: http://localhost:5000/api-docs

**That's it!** See [GETTING_STARTED.md](GETTING_STARTED.md) for detailed setup.

---

## 📚 Documentation

### Essential Guides
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup guide for new developers
- **[START_EVERYTHING.md](START_EVERYTHING.md)** - Detailed service startup instructions
- **[SKAFFOLD_QUICK_START.md](SKAFFOLD_QUICK_START.md)** - Quick Skaffold + Kubernetes guide
- **[SKAFFOLD_CONFIGS.md](SKAFFOLD_CONFIGS.md)** - Skaffold config files guide (local vs cloud)
- **[FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)** - Find tasks and responsibilities by role
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[docs/SKAFFOLD_SETUP.md](docs/SKAFFOLD_SETUP.md)** - Complete Skaffold documentation

### Team-Specific Guides
- **AI Team** → [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md)
- **Backend Team** → [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md)
- **Frontend Team** → [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)
- **ML Team** → [docs/ML_ENGINEER_COMPLETE_GUIDE.md](docs/ML_ENGINEER_COMPLETE_GUIDE.md)
- **ML Ops** → [docs/MLOPS_TEAM_ONBOARDING.md](docs/MLOPS_TEAM_ONBOARDING.md)
- **Platform Team** → [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)
- **QA Team** → [docs/SECURITY_QA_TEAM_ONBOARDING.md](docs/SECURITY_QA_TEAM_ONBOARDING.md)

### Docker & Scripts
- **[scripts/README.md](scripts/README.md)** - All available scripts explained
- **[docs/DOCKER-IMAGE-CLEANSING-COMMANDS.md](docs/DOCKER-IMAGE-CLEANSING-COMMANDS.md)** - Docker cleanup guide
- **[docs/MAKEFILE-EXPLANATION.md](docs/MAKEFILE-EXPLANATION.md)** - Makefile usage (optional)

### Architecture & System
- **[docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md)** - System design overview
- **[docs/MICROSERVICES_ARCHITECTURE.md](docs/MICROSERVICES_ARCHITECTURE.md)** - Microservices details
- **[DOCUMENTATION-INDEX.md](DOCUMENTATION-INDEX.md)** - Complete index of all 63+ docs

---

## 🛠️ Common Tasks

### Starting Services

**⭐ PRIMARY: Kubernetes with Skaffold**
```bash
# Setup Minikube (first time only)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# Start with Skaffold (uses skaffold-local.yaml)
./scripts/start-skaffold-dev.sh        # Linux/Mac
.\scripts\start-skaffold-dev.ps1       # Windows

# Or directly
skaffold dev -f skaffold-local.yaml --port-forward
```

**Alternative: Docker Compose**
```bash
# Normal start (no rebuild)
docker compose -f docker-compose.dev.yml up -d

# Rebuild and start (after code changes)
./rebuild.sh        # Linux/Mac
.\rebuild.ps1       # Windows
```

### Stopping Services

**⭐ PRIMARY: Kubernetes with Skaffold**
```bash
# Press Ctrl+C in Skaffold terminal (auto-cleanup)
# Or manually:
./scripts/stop-skaffold.sh        # Linux/Mac
.\scripts\stop-skaffold.ps1       # Windows
```

**Alternative: Docker Compose**
```bash
docker compose -f docker-compose.dev.yml down
```

### Viewing Logs
```bash
# All services
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f cyrex
```

### Rebuilding (Only When Needed)
```bash
# Full clean rebuild
./rebuild.sh        # Linux/Mac
.\rebuild.ps1       # Windows

# Rebuild cyrex with auto GPU detection (recommended)
# Windows
.\scripts\build-cyrex-auto.ps1

# Linux/Mac
./scripts/build-cyrex-auto.sh

# Manual rebuild specific service
docker compose -f docker-compose.dev.yml build --no-cache cyrex
docker compose -f docker-compose.dev.yml up -d cyrex
```

**Note:** Normal `docker compose up` does NOT rebuild - it uses existing images. Only rebuild when code changes!

**GPU Detection:** The build system automatically detects your GPU and chooses the best base image (CUDA if GPU ≥4GB, CPU otherwise). This prevents build freezing from large CUDA downloads. See `diri-cyrex/README_BUILD.md` for details.

---

## 📁 Project Structure

```
deepiri/
├── README.md                    # You are here! Start here.
├── GETTING_STARTED.md           # Detailed setup guide
├── START_EVERYTHING.md          # Service startup guide
├── rebuild.sh / rebuild.ps1     # Main rebuild scripts (root for easy access)
├── Makefile                     # Optional make commands
│
├── scripts/                     # All utility scripts
│   ├── README.md                # Script documentation
│   ├── cleanup-*.sh/ps1        # Cleanup scripts
│   └── archive/                 # Old/legacy scripts
│
├── docs/                        # All documentation
│   ├── *_TEAM_ONBOARDING.md    # Team guides
│   ├── TROUBLESHOOTING.md      # Common issues
│   └── DOCKER-*.md             # Docker guides
│
├── deepiri-web-frontend/        # React frontend
├── deepiri-core-api/            # Node.js backend
├── diri-cyrex/              # Python AI agent
├── platform-services/           # Platform microservices
│   ├── backend/                 # Backend microservices
│   ├── shared/                  # Shared utilities
│   ├── ai-ml/                   # AI/ML services (future)
│   └── data/                    # Data processing services (future)
└── docker-compose.dev.yml       # Docker configuration
```

---

## 🎯 Core Concept

Gamify your productivity by turning tasks, study material, coding projects, or creative work into mini-games, challenges, and interactive experiences. Rewards, progress tracking, and adaptive difficulty make boring tasks fun. AI adapts challenges to your workflow and style, with optional multiplayer/competitive features.

## 🏗️ Architecture

Deepiri follows a modern microservices architecture:

### Backend Services
- **User Service**: Authentication, profiles, progress, preferences
- **Task Service**: CRUD tasks, fetch tasks from integrations, store metadata
- **AI Challenge Service**: Generates challenges from tasks using NLP + RL models
- **Gamification Service**: Points, badges, leaderboards, streaks
- **Analytics Service**: Tracks performance, creates insights, suggests optimizations
- **Notification Service**: Sends reminders, daily missions, streak updates
- **Integration Service**: Connects to Notion, Trello, Google Docs, GitHub

### Python Agent (FastAPI)
- **AI Challenge Generation**: NLP models for task parsing and challenge creation
- **Reinforcement Learning**: Adaptive difficulty optimization
- **Task Understanding**: Classifies and categorizes tasks

### Frontend (React + Vite)
- **Modern React 18**: Hooks, Context API, and modern patterns
- **Responsive Design**: Mobile-first design with Tailwind CSS
- **Real-time Updates**: Socket.IO integration for live progress
- **Progressive Web App**: Offline support and mobile optimization

### Database & Infrastructure
- **MongoDB**: Primary database for all application data
- **Redis**: Caching layer and leaderboard storage
- **Docker**: Containerized deployment
- **NGINX**: Load balancing and reverse proxy

---

## ⚙️ Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

```bash
# Required API Keys
OPENAI_API_KEY=your_openai_api_key

# Database
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=your_secure_password
MONGO_DB=deepiri
REDIS_PASSWORD=your_redis_password

# JWT Secret
JWT_SECRET=your_jwt_secret_key
```

See [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) for complete list.

---

## 🧪 Testing

```bash
# Backend tests
cd deepiri-core-api && npm test

# Python agent tests
cd diri-cyrex && pytest -q

# Frontend tests
cd deepiri-web-frontend && npm test
```

---

## 🚢 Deployment

### Production with Docker
```bash
export NODE_ENV=production
docker compose --profile production up -d
```

### Cloud Deployment
Designed for cloud-native deployment on:
- **AWS**: ECS, EKS, or EC2
- **Google Cloud**: GKE or Cloud Run
- **Azure**: AKS or Container Instances
- **DigitalOcean**: App Platform or Kubernetes

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `npm test`
5. Commit: `git commit -m "Add feature"`
6. Push: `git push origin feature-name`
7. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📖 API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:5000/api-docs

### Main Endpoints
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `POST /api/tasks` - Create new task
- `GET /api/tasks` - Get user's tasks
- `POST /api/challenges/generate` - Generate challenge from task
- `GET /api/gamification/profile` - Get user progress

---

## 🆘 Support

### Common Issues

**Port already in use**
```bash
docker compose -f docker-compose.dev.yml down
```

**Docker storage bloat (50GB+ images)**
```bash
./rebuild.sh        # Linux/Mac
.\rebuild.ps1       # Windows
```

**Database connection issues**
```bash
docker compose -f docker-compose.dev.yml up -d mongodb
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- OpenAI for GPT-4 integration
- React and Node.js communities
- Hugging Face for transformer models

---

**Need help?** Check [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md) or [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
