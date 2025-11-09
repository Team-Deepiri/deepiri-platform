# Deepiri Environment Setup Guide

Complete guide for setting up the Deepiri development environment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Setup](#detailed-setup)
4. [Service-Specific Setup](#service-specific-setup)
5. [Development Tools](#development-tools)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Node.js** 18.x or higher
- **Python** 3.10 or higher
- **Docker** and **Docker Compose**
- **Git**
- **MongoDB** 6.0+ (or use Docker)
- **Redis** 7.0+ (or use Docker)

### Optional but Recommended

- **CUDA-capable GPU** (for AI training)
- **VS Code** or your preferred IDE
- **Postman** or **Insomnia** (for API testing)
- **MongoDB Compass** (for database management)

### System Requirements

- **RAM:** Minimum 8GB, Recommended 16GB+
- **Storage:** Minimum 20GB free space
- **OS:** Windows 10+, macOS 10.15+, or Linux (Ubuntu 20.04+)

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd Deepiri/deepiri

# Copy environment files
cp env.example .env
cp env.example.docker docker-compose.env

# Edit .env with your configuration
# Add API keys: OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.

# Start all services
docker-compose -f docker-compose.dev.yml up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

Services will be available at:
- Frontend: http://localhost:3000
- Backend API: http://localhost:5000
- Python AI Service: http://localhost:8000
- MongoDB: localhost:27017
- Redis: localhost:6379
- Mongo Express: http://localhost:8081

### Option 2: Local Development

See [Detailed Setup](#detailed-setup) section below.

## Detailed Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd Deepiri/deepiri
```

### 2. Environment Configuration

```bash
# Copy environment templates
cp env.example .env
cp env.example.server api-server/.env
cp env.example.client frontend/.env
cp env.example.python python_backend/.env

# Edit each .env file with your configuration
```

#### Required Environment Variables

**Root `.env`:**
```bash
NODE_ENV=development
API_URL=http://localhost:5000
AI_SERVICE_URL=http://localhost:8000
MONGODB_URI=mongodb://localhost:27017/deepiri
REDIS_URL=redis://localhost:6379
```

**`api-server/.env`:**
```bash
PORT=5000
MONGODB_URI=mongodb://localhost:27017/deepiri
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key-here
FIREBASE_PROJECT_ID=your-firebase-project
```

**`frontend/.env`:**
```bash
VITE_API_URL=http://localhost:5000
VITE_AI_SERVICE_URL=http://localhost:8000
VITE_FIREBASE_API_KEY=your-firebase-key
```

**`python_backend/.env`:**
```bash
OPENAI_API_KEY=your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
HUGGINGFACE_API_KEY=your-huggingface-key
LOCAL_MODEL_PATH=/path/to/local/model
PREFERRED_MODEL_TYPE=openai
```

### 3. Database Setup

#### MongoDB

**Using Docker:**
```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -v mongodb_data:/data/db \
  mongo:6.0
```

**Using Local Installation:**
```bash
# macOS
brew install mongodb-community
brew services start mongodb-community

# Ubuntu
sudo apt-get install mongodb
sudo systemctl start mongodb

# Windows
# Download and install from mongodb.com
```

#### Redis

**Using Docker:**
```bash
docker run -d \
  --name redis \
  -p 6379:6379 \
  redis:7-alpine
```

**Using Local Installation:**
```bash
# macOS
brew install redis
brew services start redis

# Ubuntu
sudo apt-get install redis-server
sudo systemctl start redis-server

# Windows
# Download and install from redis.io
```

### 4. Backend Setup

```bash
cd api-server

# Install dependencies
npm install

# Run database migrations (if any)
npm run migrate

# Start development server
npm run dev
```

Backend will run on http://localhost:5000

### 5. Python AI Service Setup

```bash
cd python_backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install additional AI dependencies
pip install torch transformers accelerate bitsandbytes

# Start FastAPI server
uvicorn app.main:app --reload --port 8000
```

Python service will run on http://localhost:8000

**For GPU Support (Training):**
```bash
# Install CUDA-enabled PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Verify GPU
python -c "import torch; print(torch.cuda.is_available())"
```

### 6. Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

Frontend will run on http://localhost:3000

### 7. Desktop IDE Setup

```bash
cd ../desktop-ide-deepiri

# Install Rust (if not installed)
# Visit rustup.rs for installation

# Install Tauri CLI
cargo install tauri-cli

# Install frontend dependencies
npm install

# Build and run
npm run tauri dev
```

## Service-Specific Setup

### Microservices Architecture

Each microservice in `services/` can be run independently:

```bash
# Example: Integration Service
cd services/integration-service
npm install
npm run dev
```

### AI Training Environment

```bash
cd python_backend

# Setup training directories
mkdir -p train/models train/data train/experiments train/notebooks

# Initialize MLflow
mlflow ui --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns

# Run training pipeline
python train/pipelines/ml_training_pipeline.py --config train/configs/ml_training_config.json
```

### MLOps Setup

```bash
cd python_backend/mlops

# Setup monitoring
# Prometheus and Grafana configs are in infrastructure/monitoring/

# Setup CI/CD
# GitHub Actions workflows are in .github/workflows/
```

## Development Tools

### VS Code Extensions (Recommended)

- Python
- Pylance
- ESLint
- Prettier
- Docker
- MongoDB
- Rust Analyzer
- Tauri

### VS Code Settings

Create `.vscode/settings.json`:
```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/python_backend/venv/bin/python",
  "python.linting.enabled": true,
  "python.formatting.provider": "black",
  "editor.formatOnSave": true,
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
```

### Git Hooks

```bash
# Install pre-commit hooks
npm install --save-dev husky
npx husky install

# Add pre-commit hook
npx husky add .husky/pre-commit "npm run lint"
```

### Database Tools

- **MongoDB Compass:** GUI for MongoDB
- **Redis Insight:** GUI for Redis
- **DBeaver:** Universal database tool

### API Testing

- **Postman:** Import collection from `docs/postman/`
- **Insomnia:** Import workspace from `docs/insomnia/`
- **Thunder Client:** VS Code extension

## Development Workflow

### Starting Development

1. Start databases (MongoDB, Redis)
2. Start backend services (API server, Python AI service)
3. Start frontend
4. Start desktop IDE (if working on it)

### Running Tests

```bash
# Backend tests
cd api-server
npm test

# Python tests
cd python_backend
pytest

# Frontend tests
cd frontend
npm test

# Integration tests
cd python_backend
pytest tests/integration/
```

### Code Quality

```bash
# Lint backend
cd api-server
npm run lint

# Format Python
cd python_backend
black .
isort .

# Lint frontend
cd frontend
npm run lint
```

## Troubleshooting

### Common Issues

#### Port Already in Use

```bash
# Find process using port
# Windows
netstat -ano | findstr :5000
# macOS/Linux
lsof -i :5000

# Kill process
# Windows
taskkill /PID <pid> /F
# macOS/Linux
kill -9 <pid>
```

#### MongoDB Connection Issues

```bash
# Check MongoDB is running
# Windows
net start MongoDB
# macOS
brew services list
# Linux
sudo systemctl status mongodb

# Test connection
mongosh mongodb://localhost:27017
```

#### Python Virtual Environment Issues

```bash
# Recreate virtual environment
cd python_backend
rm -rf venv
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
```

#### Docker Issues

```bash
# Reset Docker containers
docker-compose down -v
docker-compose up -d

# View logs
docker-compose logs -f <service-name>

# Rebuild images
docker-compose build --no-cache
```

#### Node Modules Issues

```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### GPU Not Detected (Python)

```bash
# Check CUDA installation
nvidia-smi

# Reinstall PyTorch with CUDA
pip uninstall torch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### Environment Variable Issues

- Ensure all `.env` files are in correct locations
- Check for typos in variable names
- Verify API keys are valid
- Restart services after changing `.env` files

### Database Migration Issues

```bash
# Reset database (WARNING: Deletes all data)
cd api-server
npm run db:reset

# Run migrations manually
npm run migrate
```

## Additional Resources

- **Architecture Documentation:** `MICROSERVICES_ARCHITECTURE.md`
- **Team READMEs:** `README_AI_TEAM.md`, `README_BACKEND_TEAM.md`, etc.
- **Contributing Guide:** `CONTRIBUTING.md`
- **API Documentation:** `api-server/docs/`

## Getting Help

1. Check team-specific README files
2. Review `FIND_YOUR_TASKS.md` for your role
3. Ask in team channels (Discord/Slack)
4. Check existing issues on GitHub
5. Contact your team lead

---

**Last Updated:** 2024
**Maintained by:** Platform Team

