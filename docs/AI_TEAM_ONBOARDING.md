# AI Team Onboarding Guide

Welcome to the Deepiri AI Team! This guide will help you get set up and start contributing.

## Quick Reference

### Setup Minikube (for Kubernetes/Skaffold builds)
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
docker compose -f docker-compose.ai-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.ai-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f jupyter
docker compose -f docker-compose.dev.yml logs -f challenge-service
# ... etc for all services
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Role-Specific Setup](#role-specific-setup)
4. [Development Workflow](#development-workflow)
5. [Key Resources](#key-resources)

## Prerequisites

### Required Software

- **Python 3.10+** (3.11 recommended)
- **CUDA-capable GPU** (for training) - NVIDIA GPU with CUDA 11.8+
- **Docker** and **Docker Compose**
- **Git**
- **VS Code** or **PyCharm** (recommended IDEs)

### Required Accounts

- **OpenAI API Key** (for challenge generation)
- **Anthropic API Key** (optional, for Claude models)
- **Hugging Face Account** (for model access)
- **Weights & Biases Account** (for experiment tracking)
- **MLflow** (local or cloud instance)

### System Requirements

- **RAM:** 16GB minimum, 32GB+ recommended for training
- **Storage:** 50GB+ free space (for models and datasets)
- **GPU:** NVIDIA RTX 3090/4090 or better (for local training)

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd deepiri-platform
```

### 2. Set Up Git Hooks (REQUIRED)

**⚠️ IMPORTANT:** This protects the `main` and `dev` branches from accidental pushes.

```bash
./setup-hooks.sh
```

This enables local Git hooks that prevent you from pushing directly to protected branches. You'll need to use Pull Requests instead.

**Why?** See [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) for details.

### 3. Docker Setup (Required)

**For WSL2 users (Recommended): Use Docker Engine instead of Docker Desktop**

```bash
# Install Docker Engine (more reliable in WSL2 than Docker Desktop)
cd deepiri
./scripts/setup-docker-wsl2.sh

# After the script completes, restart WSL2:
# In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify Docker installation
docker --version
docker-compose --version
docker ps
```

**What the script does:**
- Installs Docker Engine, Buildx, and Compose (official Docker packages)
- Verifies Docker's official GPG key fingerprint (security check)
- Configures WSL2 for systemd
- See [QUICK-START-SCRIPTS.md](../QUICK-START-SCRIPTS.md) for manual installation steps

### 3. Python Environment Setup

```bash
cd diri-cyrex

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# Install base dependencies
pip install -r requirements.txt

# Install AI-specific dependencies
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install transformers accelerate bitsandbytes
pip install mlflow wandb
pip install jupyter notebook

# Install new AI service dependencies
pip install peft  # For LoRA adapters
pip install gymnasium  # For RL environment
pip install @influxdata/influxdb-client  # For time-series analytics
pip install pinecone-client  # For vector database (optional)
pip install weaviate-client  # For vector database (optional)
pip install kubernetes  # For MLOps deployment
pip install prometheus-client  # For monitoring
```

### 3. Environment Configuration

```bash
# Copy environment template
cp env.example.python .env

# Edit .env with your API keys
# Required:
OPENAI_API_KEY=your-key-here
ANTHROPIC_API_KEY=your-key-here (optional)
HUGGINGFACE_API_KEY=your-key-here
WANDB_API_KEY=your-key-here

# Model configuration
LOCAL_MODEL_PATH=/path/to/local/model (optional)
PREFERRED_MODEL_TYPE=openai

# MLOps Configuration
MLFLOW_TRACKING_URI=http://localhost:5000
MODEL_REGISTRY_PATH=./model_registry
STAGING_MODEL_PATH=./models/staging
PRODUCTION_MODEL_PATH=./models/production

# Vector Database (for Enhanced RAG)
PINECONE_API_KEY=your-pinecone-key (optional)
PINECONE_ENVIRONMENT=us-east1-gcp
PINECONE_INDEX=deepiri
WEAVIATE_URL=http://localhost:8080 (optional)

# InfluxDB (for time-series analytics)
INFLUXDB_URL=http://localhost:8086
INFLUXDB_TOKEN=your-influxdb-token
INFLUXDB_ORG=deepiri
INFLUXDB_BUCKET=analytics
```

### 4. Verify GPU Setup

```bash
python -c "import torch; print(f'CUDA Available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"
```

### 5. Initialize Training Directories

```bash
mkdir -p train/models train/data train/experiments train/notebooks
mkdir -p inference/models inference/pipelines
mkdir -p mlops/ci mlops/monitoring mlops/deployment mlops/registry
mkdir -p adapters  # For LoRA adapters
mkdir -p model_registry models/staging models/production
```

### 6. Build and Start Required Microservices (AI Team)

**AI team only needs these services:**
- Python Agent (main AI service) - **cyrex**
- Jupyter (for experimentation)
- MLflow (for experiment tracking)
- MongoDB (for data storage)
- InfluxDB (for time-series analytics)
- Challenge Service (for AI integration testing)
- Redis (for caching, optional)

**Important: Build cyrex with GPU Detection (Recommended)**

```bash
# Auto-detect GPU and build cyrex/jupyter (recommended)
# Windows
.\scripts\build-cyrex-auto.ps1

# Linux/Mac
./scripts/build-cyrex-auto.sh

# This automatically:
# - Detects if you have a GPU (≥4GB VRAM)
# - Uses CUDA image if GPU is good enough
# - Falls back to CPU image if no GPU (faster, no freezing!)
# - Prevents build freezing from large CUDA downloads
```

**Then start services:**

```bash
# Start only the services needed for AI development
docker-compose -f docker-compose.dev.yml up -d \
  mongodb \
  redis \
  influxdb \
  cyrex \
  jupyter \
  mlflow \
  challenge-service

# Check service status
docker-compose -f docker-compose.dev.yml ps

# View logs
docker-compose -f docker-compose.dev.yml logs -f cyrex
docker-compose -f docker-compose.dev.yml logs -f jupyter
docker-compose -f docker-compose.dev.yml logs -f mlflow
```

**Note:** If you encounter build freezing at step 113/120, the auto-build script will use CPU fallback automatically. See `diri-cyrex/README_BUILD.md` for troubleshooting.

**AI Team Services:**
- **Python Agent:** cyrex (port 8000) - Main AI service
- **Jupyter:** jupyter (port 8888) - For experimentation
- **MLflow:** mlflow (port 5500) - Experiment tracking
- **Databases:** mongodb, influxdb, redis
- **Challenge Service:** challenge-service (port 5007) - For AI integration testing

**Services NOT needed for AI team:**
- `api-gateway` (unless testing full integration)
- `deepiri-web-frontend-dev` (deepiri-web-frontend team)
- `user-service`, `task-service`, etc. (backend team)
- `mongo-express` (optional, for database admin)

### 7. Start MLflow UI

```bash
# MLflow is already running via docker-compose above
# Access at http://localhost:5500

# Or start manually (if not using Docker)
mlflow ui --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns
# Access at http://localhost:5000 (if not using Docker)
```

**Note:** MLflow runs on port 5500 in Docker to avoid conflict with user-service (port 5001) and API Gateway (port 5000)

### 8. Stop Services (When Done)

```bash
# Stop all AI-related services
docker-compose -f docker-compose.dev.yml stop \
  cyrex \
  jupyter \
  mlflow \
  challenge-service

# Or stop everything
docker-compose -f docker-compose.dev.yml down
```

## Role-Specific Setup

### AI Research Lead

**Additional Setup:**
```bash
# Install research tools
pip install optuna hyperopt
pip install tensorboard
pip install plotly seaborn

# Setup experiment tracking
wandb login
mlflow ui
```

**First Tasks:**
1. Review `diri-cyrex/train/README.md`
2. Review `docs/MICROSERVICES_SETUP.md` - Understand service architecture
3. Review Python AI Service integration with microservices
4. Review existing experiments in `train/experiments/`
5. Set up experiment tracking dashboard (MLflow)
6. Review model performance metrics
7. Coordinate with research scientists on priorities
8. Test Python AI Service → Challenge Service communication

**Key Files:**
- `diri-cyrex/train/infrastructure/experiment_tracker.py`
- `diri-cyrex/train/experiments/research_experiment_template.py`
- `diri-cyrex/mlops/monitoring/model_monitor.py` - Model monitoring
- `diri-cyrex/mlops/registry/model_registry.py` - Model registry
- `diri-cyrex/mlops/ci/model_ci_pipeline.py` - CI/CD pipeline
- `diri-cyrex/mlops/deployment/deployment_automation.py` - Deployment automation
- `platform-services/backend/deepiri-challenge-service/server.js` - Challenge service (calls Python AI)

---

### AI Research Scientist 1 (Joe Hauer)

**Additional Setup:**
```bash
# Install novel architecture libraries
pip install mamba-ssm
pip install flash-attn --no-build-isolation
pip install xformers

# Install optimization libraries
pip install torch-optimizer
pip install lion-pytorch
```

**First Tasks:**
1. Review `diri-cyrex/train/experiments/research_experiment_template.py`
2. Create experiment for Mamba architecture: `train/experiments/mamba_architecture.py`
3. Create MoE experiment: `train/experiments/moe_gamification.py`
4. Explore neuro-symbolic AI: `app/services/neuro_symbolic_challenge.py`
5. Set up Jupyter notebook for experimentation

**Key Files:**
- `diri-cyrex/train/experiments/research_experiment_template.py`
- `diri-cyrex/train/notebooks/` (create your notebooks here)
- `diri-cyrex/app/services/neuro_symbolic_challenge.py`

**Experiment Template:**
```python
# train/experiments/mamba_architecture.py
from train.infrastructure.experiment_tracker import ExperimentTracker

tracker = ExperimentTracker("mamba_gamification_v1")

# Your experiment code here
```

---

### AI Research Scientist 2

**Additional Setup:**
```bash
# Install multimodal libraries
pip install clip-by-openai
pip install transformers[vision]
pip install torchvision
pip install librosa  # for audio
pip install networkx  # for graph neural networks
```

**First Tasks:**
1. Review `app/services/multimodal_understanding.py`
2. Create multimodal fusion experiment
3. Set up graph neural network experiments
4. Explore reasoning frameworks

**Key Files:**
- `diri-cyrex/app/services/multimodal_understanding.py`
- `diri-cyrex/train/experiments/multimodal/` (create directory)

---

### AI Research Scientist 3

**Additional Setup:**
```bash
# Install compression libraries
pip install auto-gptq
pip install optimum
pip install onnx onnxruntime-gpu
pip install tensorrt
pip install peft  # for LoRA/PEFT
```

**First Tasks:**
1. Review `train/infrastructure/lora_training.py`
2. Set up quantization experiments
3. Explore federated learning setup
4. Test model compression techniques

**Key Files:**
- `diri-cyrex/train/infrastructure/lora_training.py`
- `diri-cyrex/train/experiments/compression/` (create directory)

---

### AI Systems Lead (Joe Black - interim)

**Additional Setup:**
```bash
# Install deployment tools
pip install kubernetes
pip install docker
pip install fastapi uvicorn
```

**First Tasks:**
1. Review `diri-cyrex/app/main.py`
2. Review all services in `app/services/`
3. Review training pipelines in `train/pipelines/`
4. Set up deployment infrastructure
5. Coordinate with AI Systems Engineers

**Key Files:**
- `diri-cyrex/app/main.py`
- `diri-cyrex/app/services/`
- `diri-cyrex/train/pipelines/`
- `diri-cyrex/mlops/`

---

### AI Systems Engineer 1

**Additional Setup:**
```bash
# Install async and API libraries
pip install aiohttp
pip install openai anthropic
pip install redis
pip install numpy  # For advanced calculations
```

**First Tasks:**
1. Review `app/services/advanced_task_parser.py` - Advanced task understanding
2. Review `app/services/adaptive_challenge_generator.py` - RL-based challenge generation
3. Review `app/services/challenge_generator.py` - Standard challenge generation
4. Review `app/services/task_classifier.py` - Basic classification
5. Review `app/services/hybrid_ai_service.py` - Model switching
6. Review `app/services/rl_environment.py` - NEW: OpenAI Gym compatible RL environment
7. Review `app/services/ppo_agent.py` - NEW: PPO agent for challenge optimization
8. Review `app/services/dynamic_lora_service.py` - NEW: Per-user LoRA adapters
9. Review `app/services/multi_agent_system.py` - NEW: Multi-agent collaboration
10. Review `app/services/cognitive_state_monitor.py` - NEW: Cognitive state tracking
11. Review `app/services/enhanced_rag_service.py` - NEW: Enhanced RAG with Pinecone/Weaviate
12. Review `app/services/procedural_content_generator.py` - NEW: Procedural content generation
13. Review `app/services/motivational_ai.py` - NEW: Motivational AI messages
14. Test API integrations
15. Optimize prompt engineering for new services

**Key Files:**
- `diri-cyrex/app/services/advanced_task_parser.py` - Advanced parsing
- `diri-cyrex/app/services/adaptive_challenge_generator.py` - Adaptive generation
- `diri-cyrex/app/services/rl_environment.py` - NEW: RL environment
- `diri-cyrex/app/services/ppo_agent.py` - NEW: PPO agent
- `diri-cyrex/app/services/dynamic_lora_service.py` - NEW: Dynamic LoRA
- `diri-cyrex/app/services/multi_agent_system.py` - NEW: Multi-agent
- `diri-cyrex/app/services/cognitive_state_monitor.py` - NEW: Cognitive monitoring
- `diri-cyrex/app/services/enhanced_rag_service.py` - NEW: Enhanced RAG
- `diri-cyrex/app/services/procedural_content_generator.py` - NEW: Procedural content
- `diri-cyrex/app/services/motivational_ai.py` - NEW: Motivational AI
- `diri-cyrex/app/services/challenge_generator.py` - Standard generation
- `diri-cyrex/app/services/task_classifier.py` - Basic classification
- `diri-cyrex/app/services/hybrid_ai_service.py` - Hybrid AI
- `diri-cyrex/app/routes/challenge.py` - API routes

**Testing API:**
```bash
# Start FastAPI server
uvicorn app.main:app --reload --port 8000

# Test endpoint
curl -X POST http://localhost:8000/api/challenge/generate \
  -H "Content-Type: application/json" \
  -d '{"task": {"title": "Write code", "description": "Implement feature"}}'
```

---

### AI Systems Engineer 2

**Additional Setup:**
Same as AI Systems Engineer 1

**First Tasks:**
1. Review personalization services
2. Review context-aware adaptation
3. Implement multi-model fallback
4. Optimize response streaming

**Key Files:**
- `diri-cyrex/app/services/context_aware_adaptation.py`
- `diri-cyrex/app/services/personalization_service.py` (create if needed)
- `diri-cyrex/app/routes/personalization.py`

---

### AI Systems Engineer 3

**Additional Setup:**
```bash
# Install distributed training libraries
pip install deepspeed
pip install ray[default]
pip install accelerate
```

**First Tasks:**
1. Review `train/pipelines/full_training_pipeline.py`
2. Review `train/pipelines/distributed_training.py`
3. Set up GPU resource management
4. Configure training job scheduling

**Key Files:**
- `diri-cyrex/train/pipelines/full_training_pipeline.py`
- `diri-cyrex/train/pipelines/distributed_training.py`
- `diri-cyrex/mlops/ci/training_pipeline.yml`

**Test Training:**
```bash
python train/pipelines/full_training_pipeline.py \
  --config train/configs/ml_training_config.json
```

---

### AI Systems Engineer 4

**Additional Setup:**
Same as AI Systems Engineer 3, plus:
```bash
pip install mlflow
pip install boto3  # for S3 model storage
```

**First Tasks:**
1. Set up model registry
2. Configure model versioning
3. Set up automated testing
4. Create deployment pipelines

**Key Files:**
- `diri-cyrex/mlops/registry/` (create)
- `diri-cyrex/mlops/ci/model_testing.yml` (create)

---

### ML Engineer 1

**Additional Setup:**
```bash
# Install RL libraries
pip install stable-baselines3
pip install gymnasium
pip install rllib
```

**First Tasks:**
1. Review `train/pipelines/bandit_training.py`
2. Create policy network training script
3. Create value network training script
4. Create actor-critic training script

**Key Files:**
- `diri-cyrex/train/pipelines/bandit_training.py`
- `diri-cyrex/train/scripts/train_policy_network.py` (create)
- `diri-cyrex/app/services/bandit_service.py` (create)

**Training Example:**
```bash
python train/pipelines/bandit_training.py \
  --dataset train/data/bandit_training.jsonl \
  --output train/models/bandit/
```

---

### ML Engineer 2 (Lennon Shikham)

**Additional Setup:**
```bash
# Install transformer fine-tuning libraries
pip install peft
pip install bitsandbytes
pip install datasets
pip install evaluate
```

**First Tasks:**
1. Review `train/scripts/train_task_classifier.py`
2. Review `train/infrastructure/lora_training.py`
3. Set up QLoRA training pipeline
4. Test quantization methods

**Key Files:**
- `diri-cyrex/train/scripts/train_task_classifier.py`
- `diri-cyrex/train/infrastructure/lora_training.py`
- `diri-cyrex/train/scripts/train_transformer_classifier.py`

**Training Example:**
```bash
python train/scripts/train_task_classifier.py \
  --base_model mistralai/Mistral-7B-v0.1 \
  --dataset train/data/task_classification.jsonl \
  --use_qlora \
  --output_dir train/models/task_classifier
```

---

### ML Engineer 3

**Additional Setup:**
```bash
# Install lightweight model libraries
pip install timm  # for EfficientNet
pip install onnxruntime
```

**First Tasks:**
1. Review challenge generator training
2. Create lightweight model training scripts
3. Set up temporal model training
4. Create ensemble training pipeline

**Key Files:**
- `diri-cyrex/train/scripts/train_challenge_generator.py`
- `diri-cyrex/train/scripts/train_lightweight_challenge_generator.py` (create)

---

### MLOps Engineer 1

**Additional Setup:**
```bash
# Install CI/CD and deployment tools
pip install kubernetes
pip install docker
```

**First Tasks:**
1. Review `mlops/ci/training_pipeline.yml`
2. Set up GitHub Actions workflows
3. Configure model registry
4. Set up GPU cloud management

**Key Files:**
- `diri-cyrex/mlops/ci/training_pipeline.yml`
- `.github/workflows/` (create workflows)

---

### MLOps Engineer 2 (Gene Han)

**Additional Setup:**
```bash
# Install monitoring tools
pip install prometheus-client
pip install grafana-api
```

**First Tasks:**
1. Review `mlops/monitoring/model_monitor.py`
2. Set up Prometheus metrics
3. Configure Grafana dashboards
4. Implement drift detection

**Key Files:**
- `diri-cyrex/mlops/monitoring/model_monitor.py`
- `diri-cyrex/mlops/monitoring/drift_detection.py` (create)

---

### Data Engineer 1

**Additional Setup:**
```bash
# Install data processing libraries
pip install kafka-python
pip install apache-airflow
pip install pandas numpy
```

**First Tasks:**
1. Review `train/pipelines/data_collection_pipeline.py`
2. Review `train/data/prepare_dataset.py`
3. Set up user behavior pipelines
4. Create real-time feature engineering

**Key Files:**
- `diri-cyrex/train/pipelines/data_collection_pipeline.py`
- `diri-cyrex/train/data/prepare_dataset.py`

---

### Data Engineer 2 (Taylor Heffington)

**Additional Setup:**
```bash
# Install privacy and quality tools
pip install presidio-analyzer
pip install diffprivlib
pip install great-expectations
```

**First Tasks:**
1. Review data preparation scripts
2. Set up PII detection
3. Implement data validation
4. Create privacy anonymization pipeline

**Key Files:**
- `diri-cyrex/train/data/prepare_dataset.py`
- `diri-cyrex/train/data/privacy_anonymization.py` (create)

---

### AI Systems Interns

**Setup:**
Follow the basic setup above, then focus on your specific area:

- **Intern 1 (Aditya Rasal):** Testing and documentation
- **Intern 2 (Daniel Milan):** Desktop IDE edge AI
- **Intern 3:** Data preprocessing
- **Intern 4:** Benchmarking
- **Intern 5:** Documentation
- **Intern 6:** QA and validation

## Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Development

- Write code in your designated area
- Write tests for new functionality
- Update documentation

### 3. Testing

```bash
# Run unit tests
pytest tests/ai/

# Run integration tests
pytest tests/integration/

# Run benchmarks
pytest tests/ai/benchmarks/ --benchmark-only
```

### 4. Commit and Push

```bash
git add .
git commit -m "feat: your feature description"
git push origin feature/your-feature-name
```

### 5. Create Pull Request

- Create PR on GitHub
- Request review from team lead
- Address feedback
- Merge after approval

## Key Resources

### Documentation

- **AI Team README:** `docs/README_AI_TEAM.md`
- **AI Services Overview:** `docs/AI_SERVICES_OVERVIEW.md` - NEW: Complete service guide
- **Training Guide:** `diri-cyrex/train/README.md`
- **MLOps Guide:** `diri-cyrex/mlops/README.md`
- **FIND_YOUR_TASKS:** `docs/FIND_YOUR_TASKS.md`

### New Advanced Services

- **Advanced Task Parser:** `diri-cyrex/app/services/advanced_task_parser.py`
  - Multimodal task understanding
  - Context-aware analysis
  - Temporal reasoning
  - Task decomposition

- **Adaptive Challenge Generator:** `diri-cyrex/app/services/adaptive_challenge_generator.py`
  - RL-based challenge generation
  - Engagement prediction
  - Creative challenge design
  - Immersive elements

### Important Directories

- `diri-cyrex/app/services/` - AI services
- `diri-cyrex/train/` - Training infrastructure
- `diri-cyrex/mlops/` - MLOps infrastructure
- `diri-cyrex/tests/ai/` - AI tests

### Communication

- Team Discord/Slack channel
- Weekly team meetings
- Code review process
- Experiment sharing

## Getting Help

1. Check `FIND_YOUR_TASKS.md` for your specific role
2. Review team README files
3. Ask in team channels
4. Contact AI Systems Lead (Joe Black)
5. Review existing code examples

---

**Welcome to the team! Let's build amazing AI systems.**



