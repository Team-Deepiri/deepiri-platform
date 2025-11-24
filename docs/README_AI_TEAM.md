# AI Team - Deepiri

## Team Overview
The AI Team is responsible for implementing NLP task understanding, challenge generation, adaptive algorithms, and model training/inference infrastructure.

## Core Responsibilities

### AI Research Lead
- Oversee LLM development and model orchestration
- Cutting-edge AI integration (Mamba, MoE, neuro-symbolic)
- Challenge generation algorithms
- Personalization models
- Multi-modal AI integration

### AI Research Scientists
- Research novel neural architectures for gamification
- Develop training methodologies for task understanding
- Experiment with cutting-edge model architectures
- Explore alternative approaches to transformer-based systems
- Research multimodal fusion techniques
- Investigate reasoning frameworks beyond chain-of-thought
- Research model compression and quantization techniques
- Explore federated learning for privacy-preserving personalization

### AI Systems Engineers
- Real-time challenge generation
- AI model orchestration
- Prompt engineering
- Training pipeline infrastructure
- Distributed computing for model training
- Model deployment infrastructure
- Inference optimization

### ML Engineers
- Train multi-armed bandit models for challenge selection
- Train policy networks for personalized challenge generation
- Train value networks for user engagement prediction
- Train actor-critic models for real-time difficulty adjustment
- Fine-tune transformer models for task classification
- Train teacher-student models for knowledge distillation
- Train quantized models for mobile deployment

### MLOps Engineers
- CI/CD for AI models
- Model versioning
- Cloud GPU management
- Performance monitoring
- Deployment automation
- Resource optimization

### Data Engineers
- User behavior pipelines
- Challenge performance analytics
- Real-time features
- Training data curation
- Data quality
- Privacy and anonymization

## Current Infrastructure

### Python AI Service
**Location**: `diri-cyrex/`
- FastAPI application
- OpenAI integration
- Challenge generation endpoints
- Task understanding pipelines
- Advanced AI services with RL and multimodal understanding

### Key Files
- `diri-cyrex/app/main.py` - FastAPI application entry point
- `diri-cyrex/app/routes/` - API routes
- `diri-cyrex/app/services/` - AI service implementations
- `diri-cyrex/train/` - Training scripts and data

### Advanced AI Services

#### Core Services
- **AdvancedTaskParser** (`advanced_task_parser.py`) - Next-generation task understanding with:
  - Fine-tuned Transformer (DeBERTa-v3) classification
  - Multimodal understanding (CLIP + LayoutLM)
  - Context awareness (Graph Neural Networks)
  - Temporal reasoning (Temporal Fusion Transformers)
  - Task decomposition and complexity scoring

- **AdaptiveChallengeGenerator** (`adaptive_challenge_generator.py`) - RL-based challenge generation:
  - Proximal Policy Optimization (PPO) for adaptation
  - Transformer-based engagement prediction
  - Creative challenge design with diffusion models
  - Real-time difficulty adjustment
  - Immersive 3D environment design

#### Supporting Services
- **TaskClassifier** - Basic NLP task classification
- **ChallengeGenerator** - Standard challenge generation
- **MultimodalTaskUnderstanding** - Multimodal input processing
- **ContextAwareAdapter** - Context-based adaptation
- **NeuroSymbolicChallengeGenerator** - Hybrid symbolic-AI challenges
- **HybridAIService** - Local/cloud model switching
- **RewardModel** - RLHF reward modeling
- **EmbeddingService** - Vector embeddings for RAG
- **InferenceService** - High-performance model inference

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

## Getting Started

### Prerequisites
- Python 3.10+
- CUDA-capable GPU (for training)
- Docker and Docker Compose
- Access to OpenAI API key

### Setup
```bash
cd diri-cyrex
pip install -r requirements.txt
cp env.example.python .env
# Add your OPENAI_API_KEY to .env
```

### Running the AI Service
```bash
# Development
uvicorn app.main:app --reload --port 8000

# Docker
docker-compose up cyrex
```

### API Endpoints
- `POST /api/challenge/generate` - Generate adaptive challenge from task
- `POST /api/task/classify` - Classify and understand task
- `POST /api/task/parse` - Advanced task parsing with multimodal understanding
- `POST /api/personalization/adapt` - Context-aware adaptation
- `POST /api/inference/generate` - Model inference endpoint
- `POST /api/rag/query` - RAG-based query processing
- `GET /health` - Health check

## Training Infrastructure Setup

### Directory Structure Needed
```
diri-cyrex/
├── train/
│   ├── models/          # Saved model checkpoints
│   ├── data/            # Training datasets
│   ├── experiments/     # Experiment tracking
│   ├── notebooks/       # Jupyter notebooks for research
│   └── scripts/         # Training scripts
├── inference/
│   ├── models/          # Deployed models
│   └── pipelines/       # Inference pipelines
└── mlops/
    ├── ci/              # CI/CD configs
    ├── monitoring/      # Model monitoring
    └── deployment/      # Deployment configs
```

### Training Data Requirements
- Task classification datasets
- Challenge generation examples
- User behavior patterns
- Gamification effectiveness metrics

### Model Training Workflow
1. Data preprocessing and curation
2. Model architecture selection
3. Training with distributed computing
4. Evaluation and validation
5. Model versioning and deployment
6. Performance monitoring

## Research Areas

### Task Understanding
- **Advanced Task Parsing**: Fine-tuned DeBERTa-v3 with multimodal understanding
- **Multimodal Processing**: CLIP + LayoutLM for images, documents, code
- **Context Awareness**: Graph Neural Networks for task relationships
- **Temporal Reasoning**: Temporal Fusion Transformers for time-based patterns
- **Task Decomposition**: AI-powered subtask breakdown and dependency analysis
- **Complexity Scoring**: Multi-factor complexity assessment

### Challenge Generation
- **Adaptive Challenge Generation**: RL-based (PPO) challenge creation
- **Engagement Prediction**: Transformer-based engagement forecasting
- **Creative Design**: Diffusion models for challenge design
- **Real-time Adaptation**: Dynamic difficulty and reward adjustment
- **Immersive Elements**: 3D environments, audio, visual effects
- **Multi-armed Bandit**: Challenge type selection optimization

### Model Optimization
- Model compression for mobile
- Quantization techniques
- Knowledge distillation
- Federated learning

## Integration Points

### Backend Integration
- REST API communication with Node.js backend
- WebSocket for real-time challenge updates
- Database access for training data

### deepiri-web-frontend Integration
- Challenge delivery endpoints
- Real-time AI response streaming
- Model output visualization

## Next Steps
1. Set up training infrastructure directories
2. Create data pipelines for user behavior
3. Implement baseline task classification model
4. Build challenge generation prototype
5. Set up model versioning system
6. Configure GPU resources for training
7. Implement experiment tracking (MLflow/Weights & Biases)

## Resources
- OpenAI API Documentation
- FastAPI Documentation
- PyTorch/TensorFlow for model training
- MLflow for experiment tracking
- Weights & Biases for experiment management

## Advanced AI Services Documentation

For detailed information on all AI services, see:
- **AI Services Overview:** `docs/AI_SERVICES_OVERVIEW.md` - Complete guide to all services
- **Service Code:** `diri-cyrex/app/services/` - Implementation details
- **API Documentation:** Check FastAPI docs at `/docs` endpoint when server is running


