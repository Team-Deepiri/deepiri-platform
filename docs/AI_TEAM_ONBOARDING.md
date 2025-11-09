# AI Team Onboarding Guide

Welcome to the Deepiri AI Team! This guide will help you get set up and start contributing.

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
cd Deepiri/deepiri
```

### 2. Python Environment Setup

```bash
cd python_backend

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
```

### 4. Verify GPU Setup

```bash
python -c "import torch; print(f'CUDA Available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"
```

### 5. Initialize Training Directories

```bash
mkdir -p train/models train/data train/experiments train/notebooks
mkdir -p inference/models inference/pipelines
mkdir -p mlops/ci mlops/monitoring mlops/deployment
```

### 6. Start MLflow UI

```bash
mlflow ui --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns
# Access at http://localhost:5000
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
1. Review `python_backend/train/README.md`
2. Review existing experiments in `train/experiments/`
3. Set up experiment tracking dashboard
4. Review model performance metrics
5. Coordinate with research scientists on priorities

**Key Files:**
- `python_backend/train/infrastructure/experiment_tracker.py`
- `python_backend/train/experiments/research_experiment_template.py`
- `python_backend/mlops/monitoring/model_monitor.py`

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
1. Review `python_backend/train/experiments/research_experiment_template.py`
2. Create experiment for Mamba architecture: `train/experiments/mamba_architecture.py`
3. Create MoE experiment: `train/experiments/moe_gamification.py`
4. Explore neuro-symbolic AI: `app/services/neuro_symbolic_challenge.py`
5. Set up Jupyter notebook for experimentation

**Key Files:**
- `python_backend/train/experiments/research_experiment_template.py`
- `python_backend/train/notebooks/` (create your notebooks here)
- `python_backend/app/services/neuro_symbolic_challenge.py`

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
- `python_backend/app/services/multimodal_understanding.py`
- `python_backend/train/experiments/multimodal/` (create directory)

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
- `python_backend/train/infrastructure/lora_training.py`
- `python_backend/train/experiments/compression/` (create directory)

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
1. Review `python_backend/app/main.py`
2. Review all services in `app/services/`
3. Review training pipelines in `train/pipelines/`
4. Set up deployment infrastructure
5. Coordinate with AI Systems Engineers

**Key Files:**
- `python_backend/app/main.py`
- `python_backend/app/services/`
- `python_backend/train/pipelines/`
- `python_backend/mlops/`

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
1. Review `app/services/advanced_task_parser.py` - NEW: Advanced task understanding
2. Review `app/services/adaptive_challenge_generator.py` - NEW: RL-based challenge generation
3. Review `app/services/challenge_generator.py` - Standard challenge generation
4. Review `app/services/task_classifier.py` - Basic classification
5. Review `app/services/hybrid_ai_service.py` - Model switching
6. Test API integrations
7. Optimize prompt engineering for new services

**Key Files:**
- `python_backend/app/services/advanced_task_parser.py` - NEW: Advanced parsing
- `python_backend/app/services/adaptive_challenge_generator.py` - NEW: Adaptive generation
- `python_backend/app/services/challenge_generator.py` - Standard generation
- `python_backend/app/services/task_classifier.py` - Basic classification
- `python_backend/app/services/hybrid_ai_service.py` - Hybrid AI
- `python_backend/app/routes/challenge.py` - API routes

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
- `python_backend/app/services/context_aware_adaptation.py`
- `python_backend/app/services/personalization_service.py` (create if needed)
- `python_backend/app/routes/personalization.py`

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
- `python_backend/train/pipelines/full_training_pipeline.py`
- `python_backend/train/pipelines/distributed_training.py`
- `python_backend/mlops/ci/training_pipeline.yml`

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
- `python_backend/mlops/registry/` (create)
- `python_backend/mlops/ci/model_testing.yml` (create)

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
- `python_backend/train/pipelines/bandit_training.py`
- `python_backend/train/scripts/train_policy_network.py` (create)
- `python_backend/app/services/bandit_service.py` (create)

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
- `python_backend/train/scripts/train_task_classifier.py`
- `python_backend/train/infrastructure/lora_training.py`
- `python_backend/train/scripts/train_transformer_classifier.py`

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
- `python_backend/train/scripts/train_challenge_generator.py`
- `python_backend/train/scripts/train_lightweight_challenge_generator.py` (create)

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
- `python_backend/mlops/ci/training_pipeline.yml`
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
- `python_backend/mlops/monitoring/model_monitor.py`
- `python_backend/mlops/monitoring/drift_detection.py` (create)

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
- `python_backend/train/pipelines/data_collection_pipeline.py`
- `python_backend/train/data/prepare_dataset.py`

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
- `python_backend/train/data/prepare_dataset.py`
- `python_backend/train/data/privacy_anonymization.py` (create)

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
- **Training Guide:** `python_backend/train/README.md`
- **MLOps Guide:** `python_backend/mlops/README.md`
- **FIND_YOUR_TASKS:** `docs/FIND_YOUR_TASKS.md`

### New Advanced Services

- **Advanced Task Parser:** `python_backend/app/services/advanced_task_parser.py`
  - Multimodal task understanding
  - Context-aware analysis
  - Temporal reasoning
  - Task decomposition

- **Adaptive Challenge Generator:** `python_backend/app/services/adaptive_challenge_generator.py`
  - RL-based challenge generation
  - Engagement prediction
  - Creative challenge design
  - Immersive elements

### Important Directories

- `python_backend/app/services/` - AI services
- `python_backend/train/` - Training infrastructure
- `python_backend/mlops/` - MLOps infrastructure
- `python_backend/tests/ai/` - AI tests

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

