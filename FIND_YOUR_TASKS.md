# FIND YOUR TASKS - Deepiri Team Guide

**Quick Navigation:** Use Ctrl+F to find your role



---

### Founding Engineer
**Reports to:** Founder
**Location:** `deepiri/` (Platform-wide)
**Stack:** System Architecture, AI Research, Scalability Planning
**Start Here:**
- Architecture docs: `deepiri/docs/SYSTEM_ARCHITECTURE.md`
- Microservices: `deepiri/docs/MICROSERVICES_SETUP.md`
- AI research: `deepiri/python_backend/train/`
**Your Tasks:**
- Technical vision
- Platform architecture
- AI research direction
- Scalability planning
- Team leadership

---

### Product Lead
**Reports to:** Founder
**Location:** `deepiri/` (Product-wide)
**Stack:** Product Management, User Research, UX Design
**Start Here:**
- Product checklist: `deepiri/docs/PRODUCT_CHECKLIST.md`
- Frontend: `deepiri/frontend/`
- User flows: `deepiri/docs/`
**Your Tasks:**
- User research
- Product-market fit
- Feature prioritization
- UX design for gamification
- Roadmap alignment

---

## AI TEAM

### AI Research Lead (AI Scientist 0)
**Reports to:** Founder
**Location:** `deepiri/python_backend/train/`
**Stack:** Python, PyTorch, Transformers, MLflow, W&B, Jupyter
**Start Here:**
- Review: `deepiri/python_backend/train/README.md`
- Experiment tracking: `deepiri/python_backend/train/infrastructure/experiment_tracker.py`
- Research templates: `deepiri/python_backend/train/experiments/research_experiment_template.py`
**Unique Mission:** Design conceptual models that define Deepiri's cognitive engine and gamification logic. Lead theoretical development of Deepiri's cognition model.
**Your Tasks:**
- Define personalization frameworks for adaptive challenge generation
- Design challenge generation theory that maps tasks → gamified challenges
- Explore model architectures conceptually (paper-level research)
- Provide research direction to engineering teams
- Maintain AI design blueprint document (`python_backend/train/README.md`)
- Oversee LLM development and model orchestration
- Coordinate cutting-edge AI integration (RAG, RL, multi-agent systems)
- Guide fine-tuning strategies for task classification and challenge generation
- Review challenge generation algorithms and cognitive load balancing models
- Establish research priorities for multimodal understanding and model compression

---

### AI Research Scientist 1 - Cognitive Task Structuring
**Reports to:** AI Research Lead & AI Systems Lead
**Location:** `deepiri/python_backend/train/experiments/`
**Stack:** Python, PyTorch, Transformers, Novel Architectures (Mamba, MoE), Custom Training Loops, Graph Neural Networks
**Start Here:**
1. **Research Template**: Start with `deepiri/python_backend/train/experiments/research_experiment_template.py` to understand experiment structure
2. **Jupyter Notebooks**: Explore `deepiri/python_backend/train/notebooks/` for existing research work
3. **Cognitive Models**: Review `deepiri/python_backend/app/services/neuro_symbolic_challenge.py` for current neuro-symbolic approaches
4. **Task Classification**: Study `deepiri/python_backend/app/services/task_classifier.py` to understand current task understanding
5. **Challenge Generation**: Review `deepiri/python_backend/app/services/challenge_generator.py` (if exists) for gamification logic
**Unique Mission:** Theorize how tasks become "challenges" in the single-player gamified system. Build theoretical frameworks for task-to-challenge conversion. Research cognitive load balancing. Study decision-making frameworks for daily planning. Explore non-transformer cognitive models (Mamba, MoE, GNN-level theory). Create mathematical models for difficulty scaling. Support → ML Engineers (not Systems).
**Your Tasks:**
- Research cognitive load balancing algorithms for challenge difficulty
- Study decision-making frameworks for daily planning and task prioritization
- Explore non-transformer cognitive models (Mamba, MoE, GNN-level theory)
- Create mathematical models for difficulty scaling based on user performance
- Research novel neural architectures for gamification logic
- Develop new training methodologies for task understanding (`task_classifier.py`)
- Experiment with Mamba and MoE architectures for task processing
- Research alternative optimization algorithms beyond Adam/AdamW
- Support ML Engineers with theoretical foundations (not systems implementation)

---

### AI Research Scientist 2 - Multimodal Understanding Theory
**Reports to:** AI Research Lead & AI Systems Lead
**Location:** `deepiri/python_backend/train/experiments/multimodal/`
**Stack:** Python, PyTorch, Multimodal Models (CLIP, BLIP), Vision Transformers, Audio Processing, Semantic Graphs, Symbolic AI
**Start Here:**
- Multimodal service: `deepiri/python_backend/app/services/multimodal_understanding.py`
- Graph neural networks: `deepiri/python_backend/train/experiments/gnn_task_relationships.py`
**Unique Mission:** Theorize how text → visuals → actions → code → audio fuse into a unified representation for task understanding and challenge generation.
**Your Tasks:**
- Research theoretical multimodal fusion for task parsing (`multimodal_understanding.py`)
- Study conceptual semantic graphs for knowledge representation
- Explore symbolic + deep hybrid models (neuro-symbolic AI)
- Provide theoretical groundwork for creative task gamification
- Create conceptual visual reasoning strategies
- Design frameworks for document parsing (PDFs, images, code repos)
- Research graph neural networks for task relationship modeling
- Support ML Engineers with multimodal research (not systems implementation)

---

### AI Research Scientist 3 - Efficiency & Model Compression Theory
**Reports to:** AI Research Lead & AI Systems Lead
**Location:** `deepiri/python_backend/train/experiments/compression/`
**Stack:** Python, PyTorch, Quantization (GPTQ, QLoRA), Pruning, Distillation, ONNX, TensorRT, Federated Learning
**Start Here:**
- LoRA training: `deepiri/python_backend/train/infrastructure/lora_training.py`
- Model compression experiments
- Federated learning: `deepiri/python_backend/train/experiments/federated_learning.py`
**Unique Mission:** Design efficient model architectures for on-device inference and cloud optimization.
**Your Tasks:**
- Study optimal quantization strategies (4-bit/8-bit with bitsandbytes)
- Explore sparse network theory for model compression
- Theorize architectures suitable for on-device inference (desktop IDE)
- Investigate federated learning frameworks theoretically
- Propose conceptual memory-efficient training paradigms
- Research LoRA adapter optimization for per-user personalization
- Design model distillation strategies for smaller, faster models
- Support AI Systems for native app inference optimization

---

### AI Systems Lead
**Reports to:** N/A
**Location:** `deepiri/python_backend/app/services/` & `deepiri/python_backend/train/pipelines/`
**Stack:** Python, FastAPI, Docker, Kubernetes, MLflow, Model Deployment
**Start Here:**
1. **Review AI Systems Architecture**: Read `deepiri/python_backend/app/services/` to understand current service structure
2. **Training Infrastructure**: Study `deepiri/python_backend/train/pipelines/` for model training workflows
3. **Main Application**: Review `deepiri/python_backend/app/main.py` to understand API structure
4. **Model Deployment**: Check `deepiri/python_backend/mlops/deployment/` for deployment automation
5. **Team Coordination**: Review code review workflows and merge processes with ML Team Lead
**Unique Mission:** Model deployment infrastructure, inference optimization, training pipeline management. Code review and merging for AI Systems team.
**Your Tasks:**
- Manage model deployment infrastructure for production
- Optimize inference pipelines for latency and cost
- Oversee training pipeline management (MLflow, W&B integration)
- Review and merge code from AI Systems Engineers
- Coordinate with ML Team Lead on model deployment strategy
- Manage GPU cluster scheduling and resource allocation
- Ensure production-grade model serving (`inference_service.py`)
- Maintain model versioning and deployment automation
- Coordinate with MLOps Engineers on CI/CD pipelines

---

### AI Systems Engineer 1 - Model Inference Routing
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/app/services/` & `deepiri/python_backend/app/routes/`
**Stack:** Python, FastAPI, OpenAI API, Anthropic API, AsyncIO, WebSockets, Model Orchestration, Routing Logic
**Start Here:**
1. **Inference Service**: Review `deepiri/python_backend/app/services/inference_service.py` for current inference routing
2. **Hybrid AI Service**: Study `deepiri/python_backend/app/services/hybrid_ai_service.py` for hybrid model selection
3. **Challenge Routes**: Check `deepiri/python_backend/app/routes/challenge.py` for challenge generation API
4. **Task Routes**: Review `deepiri/python_backend/app/routes/task.py` for task processing endpoints
5. **Agent Routes**: Study `deepiri/python_backend/app/routes/agent.py` for agent interaction endpoints
6. **Model Selector**: Check `deepiri/python_backend/app/services/model_selector.py` for model selection logic
7. **Caching Strategy**: Review caching implementation for repeated queries
**Unique Mission:** Develop inference-routing logic for both web and native app platforms. Build orchestration logic for model selection (`model_selector.py`). Optimize prompt processing pipelines for FastAPI endpoints. Route requests between task-agent ↔ plan-agent ↔ code-agent. Reduce latency in challenge generation API (`/api/challenges/generate`). Design fallback models for weak connectivity scenarios. Implement caching strategies for repeated queries. Optimize batch processing for concurrent requests. Monitor inference performance and latency metrics.
**Your Tasks:**
- Build orchestration logic for model selection (`model_selector.py`)
- Optimize prompt processing pipelines for FastAPI endpoints
- Route requests between task-agent ↔ plan-agent ↔ code-agent
- Reduce latency in challenge generation API (`/api/challenges/generate`)
- Design fallback models for weak connectivity scenarios
- Implement caching strategies for repeated queries
- Optimize batch processing for concurrent requests
- Monitor inference performance and latency metrics
**Files to Work On:**
- `deepiri/python_backend/app/services/inference_service.py` - Inference routing
- `deepiri/python_backend/app/services/model_selector.py` - Model selection logic
- `deepiri/python_backend/app/services/agent_routing.py` - Agent routing
- `deepiri/python_backend/app/routes/challenge.py` - API routes
- `deepiri/python_backend/app/routes/task.py` - Task routes
- `deepiri/python_backend/app/routes/agent.py` - Agent routes

---

### AI Systems Engineer 2 - Agent Interaction Framework
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/app/services/`
**Stack:** Python, FastAPI, AsyncIO, Message Queues, Multi-Agent Systems, Safety Frameworks
**Start Here:**
1. **Multi-Agent System**: Review `deepiri/python_backend/app/services/multi_agent_system.py` to understand current agent architecture
2. **Context Adaptation**: Study `deepiri/python_backend/app/services/context_aware_adaptation.py` for context handling
3. **RL Agent**: Check `deepiri/python_backend/app/services/ppo_agent.py` for reinforcement learning integration
4. **Message Routing**: Review existing service communication patterns in `deepiri/python_backend/app/services/`
5. **Safety Frameworks**: Look for existing guardrails in `deepiri/python_backend/app/middleware/` or `deepiri/python_backend/app/services/`
**Unique Mission:** Build and maintain internal messaging framework for multi-agent reasoning. Architect agent → agent communication layers (`multi_agent_system.py`). Build reasoning loop frameworks for collaborative AI agents. Add safety + guardrails + alignment mechanisms. Support model orchestration during complex tasks. Implement agent coordination protocols. Design error handling and recovery for agent failures. Build agent state management and context sharing. Ensure agent outputs align with challenge generation requirements.
**Your Tasks:**
- Architect agent → agent communication layers (`multi_agent_system.py`)
- Build reasoning loop frameworks for collaborative AI agents
- Add safety + guardrails + alignment mechanisms
- Support model orchestration during complex tasks
- Implement agent coordination protocols
- Design error handling and recovery for agent failures
- Build agent state management and context sharing
- Ensure agent outputs align with challenge generation requirements
**Files to Work On:**
- `deepiri/python_backend/app/services/multi_agent_system.py` - Multi-agent coordination
- `deepiri/python_backend/app/services/context_aware_adaptation.py` - Context adaptation
- `deepiri/python_backend/app/services/ppo_agent.py` - PPO agent

---

### AI Systems Engineer 3 - Distributed Training Infrastructure
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/train/pipelines/` & `deepiri/python_backend/mlops/`
**Stack:** Python, PyTorch, Distributed Training (DeepSpeed, Ray, Slurm), Kubernetes, MLflow, GPU Clusters
**Start Here:**
- Training pipeline: `deepiri/python_backend/train/pipelines/full_training_pipeline.py`
- Distributed training: `deepiri/python_backend/train/pipelines/distributed_training.py`
- MLOps: `deepiri/python_backend/mlops/`
**Unique Mission:** Own cloud-side scaling + distributed model training.
**Your Tasks:**
- Build Ray/K8s/Slurm-style distributed training infrastructure
- Manage GPU cluster scheduling (RTX 4090s, H100s)
- Optimize multiprocessing for training pipelines
- Implement data parallelism and model parallelism (DeepSpeed ZeRO)
- Configure distributed training for LoRA adapters
- Manage training job queues and resource allocation
- Optimize training data loading and preprocessing
- Coordinate with MLOps Engineers on training automation
**Files to Work On:**
- `deepiri/python_backend/train/pipelines/distributed_training.py`
- `deepiri/python_backend/mlops/ci/training_pipeline.yml`
- `deepiri/python_backend/mlops/deployment/model_deployment.py`

---

### AI Systems Engineer 4 - Production-Grade Model Serving
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/mlops/deployment/` & `deepiri/python_backend/app/services/`
**Stack:** Python, FastAPI, Model Serving (Triton, vLLM), Kubernetes, Batching, Concurrency, Versioning
**Start Here:**
- Inference service: `deepiri/python_backend/app/services/inference_service.py`
- MLOps deployment: `deepiri/python_backend/mlops/deployment/deployment_automation.py`
- Model registry: `deepiri/python_backend/mlops/registry/model_registry.py`
**Unique Mission:** Build resilient serving infrastructure for both web and desktop IDE platforms.
**Your Tasks:**
- Production inference servers (FastAPI + Uvicorn)
- Build scalable model-serving endpoints (`/api/challenges/*`, `/api/tasks/*`)
- Optimize batching + concurrency for high-throughput
- Handle versioned deployment across web and desktop platforms
- Implement model A/B testing infrastructure
- Build model health monitoring and auto-scaling
- Optimize GPU memory usage for concurrent requests
- Work closely with MLOps Engineers on deployment pipelines
**Files to Work On:**
- `deepiri/python_backend/app/services/inference_service.py` - Inference serving
- `deepiri/python_backend/mlops/deployment/deployment_automation.py` - Deployment
- `deepiri/python_backend/mlops/registry/model_registry.py` - Model registry

---

### ML Engineer 0 (ML Team Lead)
**Reports to:** Founder
**Location:** `deepiri/python_backend/train/` & `deepiri/python_backend/mlops/`
**Stack:** Python, PyTorch, ML Strategy, Model Architecture, Cross-team Coordination
**Start Here:**
- Training README: `deepiri/python_backend/train/README.md`
- ML config: `deepiri/python_backend/app/train/configs/ml_training_config.json`
- MLOps README: `deepiri/python_backend/mlops/README.md`
**Unique Mission:** Orchestrate ML strategy, technical direction, and cross-team alignment. Does NOT merge code (AI Systems Lead reviews and merges).
**Your Tasks:**
- Technical architecture and model strategy for Deepiri's AI systems
- Resource allocation and project prioritization across ML team
- Cross-functional collaboration with product/engineering teams
- ML system design and scalability planning
- Team mentorship and technical guidance
- Model deployment governance and quality standards
- Coordinate with AI Research Lead on research priorities
- Align ML roadmap with product roadmap
- Review model performance metrics and optimization opportunities

---

### ML Engineer 1 — Gamification & Reinforcement Learning
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/train/scripts/` & `deepiri/python_backend/app/services/`
**Stack:** Python, PyTorch, Reinforcement Learning (RLlib, Stable-Baselines3), Multi-Armed Bandits, Actor-Critic
**Start Here:**
1. **Bandit Training Pipeline**: Review `deepiri/python_backend/train/pipelines/bandit_training.py` for recommendation algorithms
2. **Bandit Service**: Study `deepiri/python_backend/app/services/bandit_service.py` for challenge recommendation logic
3. **PPO Agent**: Check `deepiri/python_backend/app/services/ppo_agent.py` for actor-critic optimization
4. **RL Environment**: Review `deepiri/python_backend/app/services/rl_environment.py` for challenge generation environment
5. **Reward Model**: Examine `deepiri/python_backend/app/services/reward_model.py` for reward function design
6. **RL Training Scripts**: Look in `deepiri/python_backend/train/scripts/` for existing RL training code
**Unique Mission:** Turn tasks → challenges using RL frameworks and reward modeling. Train reward models (`reward_model.py`) for challenge generation. Build challenge selection policies using RL algorithms. Actor-critic optimization for adaptive difficulty (`ppo_agent.py`). Personalized difficulty engines based on user performance. Implement RL environment for challenge generation (`rl_environment.py`). Train bandit algorithms for challenge recommendation (`bandit_service.py`). Optimize reward functions for user engagement. Integrate RL models with challenge generation pipeline.
**Your Tasks:**
- Train reward models (`reward_model.py`) for challenge generation
- Build challenge selection policies using RL algorithms
- Actor-critic optimization for adaptive difficulty (`ppo_agent.py`)
- Personalized difficulty engines based on user performance
- Implement RL environment for challenge generation (`rl_environment.py`)
- Train bandit algorithms for challenge recommendation (`bandit_service.py`)
- Optimize reward functions for user engagement
- Integrate RL models with challenge generation pipeline

---

### ML Engineer 2 - Transformers, Distillation, Task Understanding
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/train/scripts/` & `deepiri/python_backend/app/services/`
**Stack:** Python, PyTorch, Transformers, PEFT/LoRA, Quantization (bitsandbytes, GPTQ), Knowledge Distillation
**Start Here:**
- Task classifier training: `deepiri/python_backend/train/scripts/train_task_classifier.py`
- Transformer training: `deepiri/python_backend/train/scripts/train_transformer_classifier.py`
- LoRA training: `deepiri/python_backend/train/infrastructure/lora_training.py`
- Task classifier service: `deepiri/python_backend/app/services/task_classifier.py`
- Advanced task parser: `deepiri/python_backend/app/services/advanced_task_parser.py`
**Unique Mission:** Train and optimize transformer models for task understanding and classification.
**Your Tasks:**
- Train task classification transformers (`task_classifier.py`)
- Create agent-teacher-student systems for model distillation
- Distill large models into smaller ones for faster inference
- Build efficient variants for on-device deployment
- Fine-tune DeBERTa-v3 for task classification
- Optimize transformer models for challenge generation
- Implement knowledge distillation pipelines
- Train models for task parsing and understanding
**Files to Work On:**
- `deepiri/python_backend/train/scripts/train_task_classifier.py`
- `deepiri/python_backend/train/scripts/train_transformer_classifier.py`
- `deepiri/python_backend/train/scripts/train_teacher_student.py`
- `deepiri/python_backend/train/scripts/train_quantized_model.py`

---

### ML Engineer 3 - Behavior & Temporal Learning
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/train/scripts/` & `deepiri/python_backend/app/services/`
**Stack:** Python, PyTorch, Lightweight Models (MobileNet, EfficientNet), Temporal Models (LSTM, GRU, Transformers), Ensemble Methods
**Start Here:**
1. **Challenge Generator Training**: Review `deepiri/python_backend/train/scripts/train_challenge_generator.py` for challenge generation models
2. **Personalization Training**: Study `deepiri/python_backend/train/scripts/train_personalization_model.py` for user personalization
3. **Session Analysis**: Check `deepiri/python_backend/app/services/session_analyzer.py` for user behavior analysis
4. **Time-Series Data**: Review `deepiri/services/analytics-service/` for user activity data
5. **Temporal Models**: Look for existing LSTM/GRU implementations in `deepiri/python_backend/train/scripts/`
6. **Behavior Data**: Check `deepiri/python_backend/train/data/` for user behavior datasets
**Unique Mission:** Model user habits and predict behavior patterns for personalization. Train temporal sequence models for user behavior prediction. Build habit-prediction networks for challenge timing. Train ensemble scoring models for user performance. Local recommendation models for challenge suggestions. Implement time-series analysis for productivity patterns. Build user behavior clustering models. Predict optimal challenge timing based on user history. Integrate behavior models with gamification service.
**Your Tasks:**
- Train temporal sequence models for user behavior prediction
- Build habit-prediction networks for challenge timing
- Train ensemble scoring models for user performance
- Local recommendation models for challenge suggestions
- Implement time-series analysis for productivity patterns
- Build user behavior clustering models
- Predict optimal challenge timing based on user history
- Integrate behavior models with gamification service

---

### MLOps Engineer 1 - CI/CD for Models
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/mlops/ci/` & `deepiri/python_backend/mlops/deployment/`
**Stack:** Python, CI/CD (GitHub Actions, GitLab CI), Kubernetes, MLflow, Docker, Prometheus, GPU Management
**Start Here:**
- **Onboarding Guide**: `deepiri/docs/MLOPS_TEAM_ONBOARDING.md` (READ THIS FIRST!)
- **CI/CD Pipeline**: `deepiri/python_backend/mlops/ci/model_ci_pipeline.py`
- **Deployment**: `deepiri/python_backend/mlops/deployment/deployment_automation.py`
- **Model Registry**: `deepiri/python_backend/mlops/registry/model_registry.py`
- **MLOps README**: `deepiri/python_backend/mlops/README.md`
- **Setup Script**: `deepiri/python_backend/mlops/scripts/setup_mlops_environment.sh`
**Unique Mission:** Automate model build → test → deploy pipelines.
**Your Tasks:**
- Model versioning with MLflow model registry
- Training automation for scheduled retraining
- GPU resource lifecycle management
- Build reproducibility for training experiments
- CI/CD pipeline configuration (`mlops/ci/training_pipeline.yml`)
- Automated model testing and validation
- Model artifact management and storage
- Integration with Kubernetes for training jobs
**Files to Work On:**
- `deepiri/python_backend/mlops/ci/model_ci_pipeline.py` - Main CI/CD pipeline
- `deepiri/python_backend/mlops/deployment/deployment_automation.py` - Deployment strategies
- `deepiri/python_backend/mlops/registry/model_registry.py` - Model registry
- `deepiri/python_backend/mlops/scripts/run_ci_pipeline.sh` - CI/CD automation
- `deepiri/python_backend/mlops/scripts/deploy_model.sh` - Deployment script

---

### MLOps Engineer 2 - Monitoring & Optimization
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/mlops/monitoring/` & `deepiri/python_backend/mlops/optimization/`
**Stack:** Python, Prometheus, Grafana, MLflow, Performance Profiling, Alerting, Cost Optimization
**Start Here:**
1. **Onboarding Guide**: Read `deepiri/docs/MLOPS_TEAM_ONBOARDING.md` FIRST for team context
2. **Model Monitoring Service**: Review `deepiri/python_backend/mlops/monitoring/model_monitor.py` for current monitoring setup
3. **Docker Infrastructure**: Check `deepiri/python_backend/mlops/docker/docker-compose.mlops.yml` for monitoring stack
4. **MLOps Documentation**: Read `deepiri/python_backend/mlops/README.md` for overall MLOps architecture
5. **Prometheus Config**: Check `deepiri/ops/prometheus/prometheus.yml` for metrics collection
6. **Grafana Dashboards**: Look for existing dashboards in `deepiri/python_backend/mlops/monitoring/dashboards/` (if exists)
7. **Cost Tracking**: Review infrastructure costs and GPU usage patterns
**Unique Mission:** Create monitoring + performance insights for AI systems. Monitor model drift and performance degradation. Track infrastructure LATENCY for inference endpoints. Create alerting dashboards for model health. Optimize AI costs (GPU usage, API calls, inference time). Performance monitoring for challenge generation API. Model A/B testing infrastructure. Resource utilization tracking and optimization. Integration with Prometheus and Grafana for metrics.
**Your Tasks:**
- Monitor model drift and performance degradation
- Track infrastructure LATENCY for inference endpoints
- Create alerting dashboards for model health
- Optimize AI costs (GPU usage, API calls, inference time)
- Performance monitoring for challenge generation API
- Model A/B testing infrastructure
- Resource utilization tracking and optimization
- Integration with Prometheus and Grafana for metrics
**Files to Work On:**
- `deepiri/python_backend/mlops/monitoring/model_monitor.py` - Main monitoring service
- `deepiri/python_backend/mlops/scripts/monitor_model.sh` - Monitoring script
- `deepiri/python_backend/mlops/docker/docker-compose.mlops.yml` - Monitoring stack

---

### Data Engineer 1 - Real-Time User Behavior Pipelines
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/train/data/` & `deepiri/python_backend/app/services/analytics/`
**Stack:** Python, Pandas, NumPy, Apache Kafka, NATS, Real-time Processing, Feature Engineering, Event Streaming
**Start Here:**
1. **Data Collection Pipeline**: Review `deepiri/python_backend/train/pipelines/data_collection_pipeline.py` for current data ingestion
2. **Dataset Preparation**: Study `deepiri/python_backend/train/data/prepare_dataset.py` for data preprocessing workflows
3. **Analytics Service**: Check `deepiri/services/analytics-service/` for time-series data handling
4. **Event Streaming**: Review existing streaming infrastructure (Kafka/NATS/Redis Streams) in `deepiri/services/`
5. **InfluxDB Integration**: Check `deepiri/services/analytics-service/src/timeSeriesAnalytics.js` for time-series storage
6. **Real-Time Features**: Look for feature generation code in `deepiri/python_backend/app/services/analytics/`
**Unique Mission:** Create real-time event pipelines to feed ML and Gamification services. Stream user activity via Kafka/NATS (or Redis Streams). Build challenge analytics pipelines. Generate real-time features for ML models. Integrate with Analytics Service for time-series data. Real-time event processing for gamification triggers. Data pipeline for user behavior tracking. Event streaming for challenge completion events. Integration with InfluxDB for time-series storage.
**Your Tasks:**
- Stream user activity via Kafka/NATS (or Redis Streams)
- Build challenge analytics pipelines
- Generate real-time features for ML models
- Integrate with Analytics Service for time-series data
- Real-time event processing for gamification triggers
- Data pipeline for user behavior tracking
- Event streaming for challenge completion events
- Integration with InfluxDB for time-series storage

---

### Data Engineer 2 - Quality, Privacy, Compliance
**Reports to:** ML Team Lead
**Location:** `deepiri/python_backend/train/data/` (Data Quality & Privacy)
**Stack:** Python, Pandas, Data Validation, Privacy Tools (Differential Privacy, PII Detection), GDPR Compliance
**Start Here:**
1. **Dataset Preparation**: Review `deepiri/python_backend/train/data/prepare_dataset.py` for current data processing
2. **Data Collection**: Study `deepiri/python_backend/train/pipelines/data_collection_pipeline.py` for data sources
3. **Privacy Tools**: Check for existing PII detection and anonymization code in `deepiri/python_backend/train/data/`
4. **Data Validation**: Look for validation schemas and quality checks
5. **GDPR Compliance**: Review data retention policies and user consent mechanisms
6. **Label Validation**: Check training dataset labeling processes
**Unique Mission:** Maintain complete data integrity & privacy constraints. Label validation for training datasets. GDPR and data minimization compliance. Data anonymization for user behavior data. Dataset curation for model training. Data quality assurance and validation. Privacy-preserving data processing. Data retention policy enforcement. Compliance with data protection regulations.
**Your Tasks:**
- Label validation for training datasets
- GDPR and data minimization compliance
- Data anonymization for user behavior data
- Dataset curation for model training
- Data quality assurance and validation
- Privacy-preserving data processing
- Data retention policy enforcement
- Compliance with data protection regulations

---

### AI Systems Intern 1
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/train/scripts/` & `deepiri/python_backend/docs/`
**Stack:** Python, PyTorch, Documentation Tools, Testing Frameworks
**Start Here:**
1. **Test Suite**: Review `deepiri/python_backend/tests/ai/` to understand testing patterns
2. **Training Scripts**: Study `deepiri/python_backend/train/scripts/` for training workflows
3. **Documentation**: Check `deepiri/docs/` for existing documentation structure
4. **AI Services**: Review `deepiri/python_backend/app/services/` to understand system architecture
5. **Training Infrastructure**: Check `deepiri/python_backend/train/infrastructure/` for training setup
**Unique Mission:** High-level documentation + assisting live training jobs. Document AI system architecture and workflows. Assist with monitoring live training jobs. Create documentation for model deployment processes. Help maintain training infrastructure documentation. Support AI Systems Engineers with documentation tasks.
**Your Tasks:**
- Support model training
- Write test cases for AI services
- Documentation for training scripts
- Test data preparation
- High-level documentation
- Assist with live training jobs
**Files to Work On:**
- `deepiri/python_backend/tests/ai/test_task_classifier.py`
- `deepiri/python_backend/tests/ai/test_challenge_generator.py`
- `deepiri/python_backend/train/scripts/README.md`
- `deepiri/docs/ai_training_guide.md`

---

### AI Systems Intern 2
**Reports to:** AI Systems Lead
**Location:** `desktop-ide-deepiri/src-tauri/src/` (Desktop/Edge AI)
**Stack:** Rust, ONNX Runtime, Quantized Models, Desktop Deployment, Testing
**Start Here:**
1. **Local LLM**: Review `desktop-ide-deepiri/src-tauri/src/local_llm.rs` for desktop inference
2. **Tauri Backend**: Study `desktop-ide-deepiri/src-tauri/src/main.rs` for desktop app structure
3. **Desktop Tests**: Check `desktop-ide-deepiri/tests/` for existing test patterns
4. **Model Quantization**: Review how models are quantized for desktop deployment
5. **Offline Capabilities**: Understand offline-first AI implementation
**Unique Mission:** Builds synthetic datagen + automation for training. Build synthetic data generation for training datasets. Automate data collection and preprocessing. Create data augmentation pipelines. Generate synthetic challenges for training.
**Your Tasks:**
- Test desktop IDE AI agent functionality
- Validate local model inference on desktop
- Test offline-first AI capabilities
- Validate desktop-to-cloud sync for AI features
- Report bugs and issues with desktop AI integration
**Files to Work On:**
- `desktop-ide-deepiri/src-tauri/src/local_llm.rs`
- `desktop-ide-deepiri/src-tauri/src/commands.rs`
- `desktop-ide-deepiri/tests/edge_ai_tests.rs`
- `desktop-ide-deepiri/tests/native_agent_tests.rs`

---

### AI Systems Intern 3 (ML Engineer Intern)
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/train/data/` & `deepiri/python_backend/train/scripts/`
**Stack:** Python, Pandas, Data Processing, ETL Pipelines, Synthetic Data Generation, Automation
**Start Here:**
1. **Dataset Preparation**: Review `deepiri/python_backend/train/data/prepare_dataset.py` for data processing
2. **Data Collection**: Study `deepiri/python_backend/train/pipelines/data_collection_pipeline.py` for data ingestion
3. **Training Scripts**: Check `deepiri/python_backend/train/scripts/` for training workflows
4. **Synthetic Data**: Look for existing synthetic data generation code
5. **ETL Pipelines**: Review data transformation pipelines
6. **Automation**: Understand training automation workflows
**Unique Mission:** Focuses on evaluating failure modes + regression tests. Evaluate AI system failure modes. Build regression tests for model updates. Test edge cases in challenge generation. Validate model outputs for correctness. Create test suites for AI services.
**Your Tasks:**
- Build synthetic data generation for training datasets
- Automate data collection and preprocessing
- Create data augmentation pipelines
- Generate synthetic challenges for training
- Automate dataset preparation workflows
**Files to Work On:**
- `deepiri/python_backend/train/data/prepare_dataset.py`
- `deepiri/python_backend/train/data/data_cleaning.py`
- `deepiri/python_backend/train/data/etl_pipeline.py`

---

### AI Systems Intern 4
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/tests/ai/benchmarks/` & `deepiri/python_backend/train/scripts/`
**Stack:** Python, Pytest, Benchmarking Tools, Performance Profiling, Regression Testing
**Start Here:**
- Benchmarks: `deepiri/python_backend/tests/ai/benchmarks/benchmark_classifier.py`
- Evaluation: `deepiri/python_backend/train/scripts/evaluate_model.py`
**Unique Mission:** Focuses on evaluating failure modes + regression tests.
**Your Tasks:**
- Evaluate AI system failure modes
- Build regression tests for model updates
- Test edge cases in challenge generation
- Validate model outputs for correctness
- Create test suites for AI services
**Files to Work On:**
- `deepiri/python_backend/tests/ai/benchmarks/benchmark_classifier.py`
- `deepiri/python_backend/train/scripts/evaluate_model.py`
- `deepiri/python_backend/tests/ai/benchmarks/benchmark_generator.py`
- `deepiri/python_backend/train/scripts/quality_metrics.py`

---

### AI Systems Intern 5
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/docs/` & `deepiri/services/shared-utils/`
**Stack:** Python, Documentation Tools, Testing, Code Quality, Refactoring
**Start Here:**
1. **Test Suite**: Review `deepiri/python_backend/tests/` for testing patterns
2. **Training README**: Read `deepiri/python_backend/train/README.md` for training context
3. **Shared Utils**: Study `deepiri/services/shared-utils/` for common utilities
4. **Code Quality**: Check for linting and code quality tools
5. **Refactoring Patterns**: Review existing refactoring approaches
6. **Documentation**: Check `deepiri/python_backend/docs/` for documentation standards
**Unique Mission:** Maintains shared-utils consistency + code refactors. Maintain shared utilities across AI services. Refactor code for consistency and maintainability. Ensure code quality standards across AI codebase. Help with code organization and structure. Support code review and refactoring efforts.
**Your Tasks:**
- Maintain shared utilities across AI services
- Refactor code for consistency and maintainability
- Ensure code quality standards across AI codebase
- Help with code organization and structure
- Support code review and refactoring efforts

---

### AI Systems Intern 6
**Reports to:** AI Systems Lead
**Location:** `deepiri/python_backend/tests/ai/` & `deepiri/python_backend/train/experiments/`
**Stack:** Python, Pytest, Simulation Frameworks, Validation Tools, QA Testing
**Start Here:**
- AI tests: `deepiri/python_backend/tests/ai/`
- Integration tests: `deepiri/python_backend/tests/integration/`
**Unique Mission:** QA Agent testing, simulation environments, validation.
**Your Tasks:**
- QA testing for AI agents and services
- Build simulation environments for testing
- Validate agent behavior and outputs
- Test multi-agent system interactions
- Create test scenarios for challenge generation

---

## MICROSERVICES / BACKEND TEAM

### Backend Lead
**Reports to:** Product Lead / Founder
**Location:** `deepiri/services/` & `deepiri/python_backend/app/`
**Stack:** Node.js, Express, Python, FastAPI, MongoDB, Redis, Microservices Architecture
**Start Here:**
- Architecture: `deepiri/docs/MICROSERVICES_SETUP.md` - **READ THIS FIRST!**
- API Gateway: `deepiri/services/api-gateway/server.js` (Port 5000)
- Services: `deepiri/services/` - Each service has its own `server.js`
- Python backend: `deepiri/python_backend/app/main.py` (Port 8000)
- Docker Compose: `deepiri/docker-compose.dev.yml`
**Unique Mission:** Oversees microservices architecture, REST/GraphQL APIs, database schema quality, cross-team coordination, service boundaries, backend correctness. Reviews and merges code for backend team.
**Your Tasks:**
- Coordinate microservices architecture (9+ services)
- API strategy for REST endpoints and WebSocket connections
- Database patterns (MongoDB, Redis, InfluxDB)
- Cross-collaboration with AI Systems and Platform engineers
- Ensure web microservices and native/local IDE backend sync layer alignment
- Review and merge code from Backend Engineers
- Establish coding standards and best practices
- Coordinate service boundaries and API contracts
- Ensure backend correctness and reliability
**Key Files:**
- `deepiri/services/api-gateway/server.js` - API Gateway (routes all requests)
- `deepiri/services/*/server.js` - Individual service servers
- `deepiri/docker-compose.dev.yml` - Service orchestration

---

### Backend Engineer 1 - External Integrations
**Reports to:** Backend Lead
**Location:** `deepiri/services/integration-service/`
**Stack:** Node.js, Express, OAuth2, REST APIs, Webhooks, External API Integration
**Start Here:**
1. **Service Server**: Start with `deepiri/services/integration-service/server.js` (Port 5006) to understand service setup
2. **Route Handlers**: Review `deepiri/services/integration-service/src/index.js` for API endpoints
3. **Webhook Service**: Study `deepiri/services/integration-service/src/webhookService.js` for webhook processing
4. **Integration README**: Read `deepiri/services/integration-service/README.md` for integration documentation
5. **OAuth Flows**: Check for existing OAuth implementations for Notion, Trello, GitHub
6. **API Gateway**: Understand how requests route through `deepiri/services/api-gateway/server.js`
**Unique Mission:** External Integrations: Notion/Trello/GitHub APIs, OAuth flows, webhook management, data synchronization.
**Your Tasks:**
- Build OAuth flows for Notion, Trello, GitHub, Google Docs
- Implement webhook management for external service updates
- Data synchronization between external services and Deepiri
- Authenticate all integration endpoints (JWT middleware)
- Ensure frontend, backend, and agent services have real-time communication
- Build integration service endpoints (`integration-service/`)
- Handle OAuth token refresh and management
- Parse and transform external service data formats
**Files to Work On:**
- `deepiri/services/integration-service/server.js` - Service server
- `deepiri/services/integration-service/src/index.js` - Route handlers
- `deepiri/services/integration-service/src/webhookService.js` - Webhook processing
- `deepiri/services/integration-service/Dockerfile` - Container definition

---

### Backend Engineer 2 - WebSocket Infrastructure
**Reports to:** Backend Lead
**Location:** `deepiri/services/websocket-service/` & `deepiri/services/notification-service/`
**Stack:** Node.js, Socket.IO, WebSockets, Real-time Systems, Redis Pub/Sub
**Start Here:**
1. **WebSocket Service**: Review `deepiri/services/websocket-service/server.js` (Port 5008) for real-time communication setup
2. **Notification Service**: Study `deepiri/services/notification-service/server.js` (Port 5005) for notification handling
3. **WebSocket Handler**: Check `deepiri/services/notification-service/src/websocketService.js` for connection management
4. **Redis Pub/Sub**: Review Redis configuration for message broadcasting
5. **Presence Tracking**: Look for user presence tracking implementations
6. **Challenge Sessions**: Understand how challenge sessions use WebSocket connections
**Unique Mission:** WebSocket infrastructure, message routing, presence tracking, active challenge sessions support.
**Your Tasks:**
- WebSocket infrastructure for real-time communication (`websocket-service/`)
- Message routing for live sessions
- Presence tracking for active users
- Active challenge sessions support
- Ensures low latency streams for cloud IDE interactions
- Syncs multiplayer state with AI orchestration layer for live "pair programming"
- Real-time challenge tracking and updates
- WebSocket connection management and scaling
**Files to Work On:**
- `deepiri/services/websocket-service/server.js` - WebSocket service
- `deepiri/services/notification-service/server.js` - Notification service
- `deepiri/services/notification-service/src/websocketService.js` - WebSocket handler
- `deepiri/services/websocket-service/Dockerfile` - Container definition

---

### Backend Engineer 3 - AI Integration & Gamification
**Reports to:** Backend Lead
**Location:** `deepiri/python_backend/app/routes/` & `deepiri/services/challenge-service/`
**Stack:** Python, FastAPI, Node.js, Express, AI Integration, State Management
**Start Here:**
1. **Challenge Service**: Review `deepiri/services/challenge-service/server.js` (Port 5007) for challenge management
2. **Challenge Routes**: Study `deepiri/python_backend/app/routes/challenge.py` (Port 8000) for AI endpoints
3. **AI Services**: Explore `deepiri/python_backend/app/services/` to understand AI service architecture
4. **State Management**: Check how challenge state is managed across services
5. **Gamification Rules**: Review gamification rule engine logic
6. **Python Service Communication**: Understand how Node.js services communicate with Python AI service (`http://pyagent:8000`)
**Unique Mission:** AI Integration: Python service communication layer, challenge state management, gamification rule engine logic.
**Your Tasks:**
- Python service communication layer (FastAPI integration)
- Challenge state management and lifecycle
- Gamification rule engine logic + challenge state lifecycle
- AI validation pipeline for challenge generation
- AI-provided instructions mapping into tasks for both native IDE and online IDE
- Manages cross-context data structures (task states, user states, challenge metadata)
- Integrate with Python AI service (`http://pyagent:8000`)
- Challenge completion tracking and reward distribution
**Files to Work On:**
- `deepiri/services/challenge-service/server.js` - Challenge service (port 5007) - Main service file
- `deepiri/python_backend/app/routes/challenge.py` - Python AI routes
- `deepiri/services/challenge-service/Dockerfile` - Container definition

---

### Backend Engineer 4 - Database & Caching
**Reports to:** Backend Lead
**Location:** `deepiri/services/*/src/` & `deepiri/python_backend/app/database/`
**Stack:** MongoDB, Redis, InfluxDB, SQL, Database Optimization, Query Performance, Data Migrations
**Start Here:**
1. **User Service**: Review `deepiri/services/user-service/server.js` (Port 5001) for time-series tracking
2. **Analytics Service**: Study `deepiri/services/analytics-service/server.js` (Port 5004) for InfluxDB integration
3. **Database Models**: Check `deepiri/python_backend/app/database/models.py` for data models
4. **Database Config**: Review `deepiri/python_backend/app/config/database.py` for connection settings
5. **Caching Layer**: Understand Redis caching implementation in `deepiri/python_backend/app/utils/cache.py`
6. **Indexing Strategy**: Review MongoDB collection indexes for performance
7. **Offline-First Sync**: Study how desktop IDE handles offline-first with sync recovery
**Unique Mission:** DB indexing strategy, caching layers, query performance optimization, database migrations.
**Your Tasks:**
- DB indexing strategy for MongoDB collections
- Caching layers (Redis, memory cache)
- Query performance optimization
- Database migrations for both local & cloud environments
- Backup + snapshot flow for persistence across devices
- Unique focus: ensures the desktop IDE can run "offline-first" without breaking sync when internet returns
- Redis caching for leaderboards and real-time data
- InfluxDB integration for time-series analytics
**Files to Work On:**
- `deepiri/services/user-service/src/timeSeriesService.js` - Time-series tracking
- `deepiri/services/analytics-service/src/timeSeriesAnalytics.js` - InfluxDB analytics
- `deepiri/python_backend/app/database/models.py` - Database models
- `deepiri/python_backend/app/utils/cache.py` - Caching utilities

---

### FullStack Engineer 1 (AI)
**Reports to:** Backend Lead
**Location:** `deepiri/frontend/src/pages/` & `deepiri/python_backend/app/routes/`
**Stack:** React, TypeScript, FastAPI, REST APIs, Real-time Updates
**Start Here:**
1. **Productivity Chat**: Review `deepiri/frontend/src/pages/ProductivityChat.jsx` for AI interaction UI
2. **Challenge Routes**: Study `deepiri/python_backend/app/routes/challenge.py` for AI endpoints
3. **AI Services**: Check `deepiri/python_backend/app/services/` for AI service integration
4. **Real-Time Updates**: Understand WebSocket integration for live AI feedback
5. **Model Output Visualization**: Review how AI responses are displayed in UI
6. **Frontend API Integration**: Check how frontend connects to AI services
**Unique Mission:** Builds UI hooks for AI interactions (cloud), visualizes model outputs + reasoning flow. Builds UI hooks for AI interactions (cloud). Visualizes model outputs + reasoning flow. Builds the real-time AI feedback loop for microservices IDE. UI → AI service API connectivity. Challenge flow integration between cloud UI and backend. Real-time AI response visualization. AI agent status and progress indicators.
**Your Tasks:**
- Builds UI hooks for AI interactions (cloud)
- Visualizes model outputs + reasoning flow
- Builds the real-time AI feedback loop for microservices IDE
- UI → AI service API connectivity
- Challenge flow integration between cloud UI and backend
- Real-time AI response visualization
- AI agent status and progress indicators

---

### FullStack Engineer 2 - Gamification UI
**Reports to:** Backend Lead
**Location:** `deepiri/frontend/src/components/gamification/` & `deepiri/services/gamification-service/`
**Stack:** React, TypeScript, Socket.IO, Real-time Updates, Animations
**Start Here:**
- Gamification service: `deepiri/services/gamification-service/server.js` (Port 5003)
- Route handlers: `deepiri/services/gamification-service/src/index.js`
- Services: `deepiri/services/gamification-service/src/multiCurrencyService.js`, `eloLeaderboardService.js`, `badgeSystemService.js`
- Frontend components: `deepiri/frontend/src/components/`
**Unique Mission:** Designs gamified progress flows, achievement animations, leaderboard systems.
**Your Tasks:**
- Designs gamified progress flows
- Achievement animations and visual effects
- Leaderboard systems UI
- Social or collaborative challenge UI
- UI effects optimized for both web and native UI frameworks
- Badge and reward visualization
- Streak tracking UI components
- Progress bar and XP visualization
**Files to Work On:**
- `deepiri/services/gamification-service/server.js` - Service server (port 5003)
- `deepiri/services/gamification-service/src/index.js` - Route handlers
- `deepiri/services/gamification-service/src/multiCurrencyService.js` - Multi-currency
- `deepiri/services/gamification-service/src/eloLeaderboardService.js` - ELO leaderboard
- `deepiri/services/gamification-service/src/badgeSystemService.js` - Badge system

---

### FullStack Engineer 3 - Integrations UI
**Reports to:** Backend Lead
**Location:** `deepiri/frontend/src/pages/integrations/` & `deepiri/services/integration-service/`
**Stack:** React, TypeScript, Node.js, OAuth2, REST APIs
**Start Here:**
1. **Integration Service**: Review `deepiri/services/integration-service/server.js` (Port 5006) for backend API
2. **Route Handlers**: Study `deepiri/services/integration-service/src/index.js` for endpoint structure
3. **Webhook Service**: Check `deepiri/services/integration-service/src/webhookService.js` for webhook processing
4. **Frontend Pages**: Explore `deepiri/frontend/src/pages/` for existing integration UI
5. **OAuth Flows**: Understand OAuth implementation for Notion, Trello, GitHub
6. **Sync Status**: Review how real-time sync status is displayed in UI
**Unique Mission:** Builds external integrations UI, OAuth connection dashboard, real-time sync status visualization.
**Your Tasks:**
- Builds external integrations UI
- OAuth connection dashboard
- Real-time sync status visualization
- Error reporting dashboard
- Device connection settings for native desktop IDE
- Integration status and health monitoring UI
- Webhook configuration interface
**Files to Work On:**
- `deepiri/services/integration-service/server.js` - Service server
- `deepiri/services/integration-service/src/index.js` - Route handlers
- `deepiri/services/integration-service/src/webhookService.js` - Webhook processing

---

### FullStack Engineer 4 - Analytics UI
**Reports to:** Backend Lead
**Location:** `deepiri/frontend/src/pages/analytics/` & `deepiri/services/analytics-service/`
**Stack:** React, TypeScript, Chart.js/D3.js, Node.js, InfluxDB, Real-time Data
**Start Here:**
1. **Analytics Service**: Review `deepiri/services/analytics-service/server.js` (Port 5004) for data API
2. **Route Handlers**: Study `deepiri/services/analytics-service/src/index.js` for endpoint structure
3. **Time-Series Analytics**: Check `deepiri/services/analytics-service/src/timeSeriesAnalytics.js` for InfluxDB queries
4. **Behavioral Clustering**: Review `deepiri/services/analytics-service/src/behavioralClustering.js` for clustering logic
5. **Predictive Modeling**: Study `deepiri/services/analytics-service/src/predictiveModeling.js` for predictions
6. **Frontend Pages**: Explore `deepiri/frontend/src/pages/analytics/` for existing dashboards
7. **Charting Libraries**: Review Chart.js/D3.js integration for data visualization
**Unique Mission:** Data visualizations, productivity metrics UI, real-time analytics integration.
**Your Tasks:**
- Data visualizations for productivity metrics
- Productivity metrics UI
- Real-time analytics integration with backend's data pipeline
- Export tools for analytics data
- Insight recommendation layout
- Time-series charts and graphs
- User behavior visualization
**Files to Work On:**
- `deepiri/services/analytics-service/server.js` - Service server (port 5004)
- `deepiri/services/analytics-service/src/index.js` - Route handlers
- `deepiri/services/analytics-service/src/timeSeriesAnalytics.js` - InfluxDB analytics
- `deepiri/services/analytics-service/src/behavioralClustering.js` - Clustering
- `deepiri/services/analytics-service/src/predictiveModeling.js` - Predictive models

---

### Systems Architect 1 - Microservices Communication
**Reports to:** Backend Lead
**Location:** `deepiri/services/` & `deepiri/docs/MICROSERVICES_SETUP.md`
**Stack:** System Design, Microservices Patterns, API Gateway, Service Mesh
**Start Here:**
- Architecture doc: `deepiri/docs/MICROSERVICES_SETUP.md` - **READ THIS FIRST!**
- API Gateway: `deepiri/services/api-gateway/server.js` (Port 5000)
- Docker Compose: `deepiri/docker-compose.dev.yml`
**Unique Mission:** Establishes new microservices communication patterns, Improves microservice communication, cloud scaling approach, native-to-cloud handshake protocol.
**Your Tasks:**
- Establishes microservices communication patterns
- Cloud scaling approach for 9+ services
- Native-to-cloud handshake protocol
- Versioning strategy for backend services
- API Gateway routing and load balancing
- Service discovery and health checks
- Inter-service communication protocols
**Files to Work On:**
- `deepiri/services/api-gateway/server.js` - API Gateway routing
- `deepiri/services/api-gateway/src/index.js` - Route definitions
- `deepiri/docker-compose.dev.yml` - Service orchestration

---

### Systems Architect 2 - Event Bus & Streaming
**Reports to:** Backend Lead
**Location:** `deepiri/services/` (Event-Driven Architecture)
**Stack:** Kafka, RabbitMQ, Event Sourcing, CQRS, Message Queues
**Start Here:**
- Services: `deepiri/services/`
**Unique Mission:** Event bus architecture, real-time stream processing, message queue logic.
**Your Tasks:**
- Event bus architecture (Redis Streams/Kafka)
- Real-time stream processing
- Message queue logic for async communication
- Distributed data consistency
- Pipeline design for analytics → ML engineers
- Event-driven architecture patterns
- Stream processing for user events

---

### Systems Architect 3 - Security & Compliance
**Reports to:** Backend Lead
**Location:** `deepiri/services/` & `deepiri/python_backend/app/middleware/`
**Stack:** Security Architecture, OAuth2, JWT, Encryption, API Security
**Start Here:**
- Middleware: `deepiri/python_backend/app/middleware/`
- Services: `deepiri/services/`
**Unique Mission:** Authentication flows, token security, data privacy requirements, API hardening.
**Your Tasks:**
- Authentication flows (JWT, OAuth)
- Token security and refresh mechanisms
- Data privacy requirements (GDPR compliance)
- API hardening and security best practices
- Compliance alignment (HIPAA/GDPR if needed)
- Rate limiting and DDoS protection
- Security audit logging

---

### Systems Architect 4 - Scaling & High Availability
**Reports to:** Backend Lead
**Location:** `deepiri/services/websocket-service/` & `deepiri/services/gamification-service/`
**Stack:** Real-time Systems, WebSockets, Scalability, Multiplayer Architecture
**Start Here:**
- WebSocket service: `deepiri/services/websocket-service/`
- Gamification service: `deepiri/services/gamification-service/`
**Unique Mission:** Scaling live sessions, game state management, global replication strategies.
**Your Tasks:**
- Scaling live sessions (WebSocket connections)
- Game state management for challenges
- Global replication strategies
- Load balancing across services
- Failover systems for cloud IDE during peak usage
- Database replication and sharding
- CDN integration for static assets

---

### Systems Architect Intern (Officially: Systems Architect)
**Reports to:** Backend Lead
**Location:** `deepiri/architecture/` & `deepiri/services/`
**Stack:** System Design, Documentation, Architecture Patterns
**Start Here:**
- Architecture docs: `deepiri/docs/MICROSERVICES_SETUP.md`
- Services: `deepiri/services/`
**Unique Mission:** Supporting system architecture design, documentation, prototyping.
**Your Tasks:**
- Documents architecture decisions
- Prototypes small architectural experiments
- Validates communication flows between services
- Creates architecture diagrams
- Assists with system design documentation

---

### Systems Engineer 1 - End-to-End Integration
**Reports to:** Product Lead / Founder
**Location:** `deepiri/` (Cross-system integration)
**Stack:** System Integration, End-to-End Testing, API Integration, System Validation
**Start Here:**
- Root: `deepiri/`
- Integration tests: `deepiri/python_backend/tests/integration/`
**Unique Mission:** Ensure the entire Deepiri system (web IDE, native desktop IDE, AI services, backend, and cloud) works seamlessly as an integrated product.
**Your Tasks:**
- Conduct end-to-end flow validation across web and desktop platforms
- Perform system-wide behavior testing (AI agents, task flow, challenge gamification)
- Coordinate with backend and AI Systems teams to detect integration issues
- Maintain test matrices for multi-service and multi-platform scenarios
- Report and prioritize system-level anomalies
- Integration testing across all microservices
- Validate AI service integration with backend

---

### Systems Engineer 2 - Visual Documentation
**Reports to:** Product Lead / Founder
**Location:** `deepiri/docs/` & `deepiri/` (Visual Documentation)
**Stack:** Documentation, Diagramming, Visual Design, Planning Tools
**Start Here:**
1. **Documentation Directory**: Review `deepiri/docs/` for existing documentation structure
2. **System Architecture**: Read `deepiri/docs/SYSTEM_ARCHITECTURE.md` for system overview
3. **Microservices Setup**: Study `deepiri/docs/MICROSERVICES_SETUP.md` for service architecture
4. **Product Documentation**: Check `deepiri/docs/PRODUCT_CHECKLIST.md` for product context
5. **Visual Tools**: Familiarize with diagramming tools used by the team
6. **Workflow Documentation**: Review existing workflow diagrams if available
**Unique Mission:** Support the Product Lead in visualizing, planning, and documenting system flows without touching software.
**Your Tasks:**
- Create physical diagrams for workflows, data flows, and user journeys
- Produce schematics for device-agent interactions (native IDE)
- Visualize task and challenge logic for planning sessions
- Maintain visual documentation for onboarding and team alignment
- Assist Product Lead with whiteboarding, brainstorming product flow diagrams, and planning sessions

---

### Platform Engineer 1 (Lead)
**Reports to:** Backend Lead
**Location:** `deepiri/platform/` & `deepiri/.github/`
**Stack:** Internal Developer Platform, CI/CD, Developer Tooling, Productivity Tools
**Start Here:**
- Platform directory: `deepiri/platform/` (create if needed)
- CI/CD: `deepiri/.github/workflows/`
- Scripts: `deepiri/scripts/*.sh`
- Environment setup: `deepiri/ENVIRONMENT_SETUP.md`
- Dev start: `deepiri/dev-start.js`
**Unique Mission:** Developer tooling, internal CLIs and workflows, productivity automation.
**Your Tasks:**
- Developer tooling for local development
- Internal CLIs and workflows
- Productivity automation for development team
- Inter-service debugging tools
- Local development environment setup
- Developer onboarding tooling

---

### Platform Engineer 2 - Infrastructure as Code
**Reports to:** Backend Lead / Platform Engineer 1
**Location:** `deepiri/infrastructure/` & `deepiri/docker-compose.yml`
**Stack:** Terraform, Infrastructure as Code, Cloud Provisioning, Docker
**Start Here:**
- Docker compose: `deepiri/docker-compose.yml`
- Infrastructure: `deepiri/infrastructure/` (create)
- Kubernetes: `deepiri/ops/k8s/*.yaml`
**Unique Mission:** Infrastructure as Code templates, automated provisioning, security practices.
**Your Tasks:**
- Infrastructure as Code templates (Terraform/CloudFormation)
- Automated provisioning of dev and prod environments
- Ensures both web + native IDE share configuration pipelines
- Embed security practices into the platform
- Manage access controls
- Ensure the platform adheres to compliance standards
- Kubernetes configuration and deployment

---

### Cloud / Infrastructure Engineer 1 (Lead)
**Reports to:** Backend Lead
**Location:** `deepiri/infrastructure/` & `deepiri/docker-compose.yml`
**Stack:** AWS/GCP/Azure, Kubernetes, Cloud Resource Management, Networking
**Start Here:**
- Docker compose: `deepiri/docker-compose.yml`
- Infrastructure: `deepiri/infrastructure/`
**Unique Mission:** Cloud resource management, networking, cost optimization.
**Your Tasks:**
- Cloud compute cluster management
- Networking layout for microservices
- Cost optimization for cloud resources
- Resource allocation and scaling
- Cloud provider integration (AWS/GCP/Azure)
- Network security and VPC configuration

---

### Cloud / Infrastructure Engineer 2 - Observability
**Reports to:** Backend Lead
**Location:** `deepiri/infrastructure/monitoring/` & `deepiri/infrastructure/security/`
**Stack:** Prometheus, Grafana, Cloud Security, Monitoring Tools
**Start Here:**
- Infrastructure: `deepiri/infrastructure/`
- Prometheus: `deepiri/ops/prometheus/prometheus.yml`
- Fluentd: `deepiri/ops/fluentd/*.conf`
**Unique Mission:** Security logging, resource utilization, bottleneck identification, observability dashboards.
**Your Tasks:**
- Security logging and audit trails
- Resource utilization monitoring
- Bottleneck identification and optimization
- Observability dashboards (Grafana, Prometheus)
- Performance monitoring and alerting
- Log aggregation and analysis

---

### Cloud / Infrastructure Engineer 3 - High Availability
**Reports to:** Backend Lead
**Location:** `deepiri/infrastructure/disaster_recovery/` & `deepiri/infrastructure/backup/`
**Stack:** Backup Systems, Disaster Recovery, High Availability, Failover
**Start Here:**
- Infrastructure: `deepiri/infrastructure/`
**Unique Mission:** Backup strategy, multi-region availability, failover systems.
**Your Tasks:**
- Backup strategy for databases and user data
- Multi-region availability
- Failover systems for high availability
- Native IDE → cloud sync recovery mechanisms
- Disaster recovery planning
- Data replication across regions

---

### DevOps Engineer
**Reports to:** Backend Lead
**Location:** `deepiri/.github/workflows/` & `deepiri/infrastructure/`
**Stack:** CI/CD, Docker, Kubernetes, Monitoring, Observability
**Start Here:**
- CI/CD: `deepiri/.github/workflows/`
- Docker: `deepiri/docker-compose.yml`
**Unique Mission:** CI/CD, monitoring, observability, deployment pipelines.
**Your Tasks:**
- CI/CD pipeline configuration
- Monitoring and alerting setup
- Observability infrastructure
- Deployment pipelines for both web services and native update service
- Automated testing in CI/CD
- Release management and versioning

---

### Backend Intern 1 (MLOps Intern)
**Reports to:** Backend Lead
**Location:** `deepiri/services/*/tests/` & `deepiri/.github/workflows/`
**Stack:** Testing, CI/CD, Test Automation
**Start Here:**
1. **Service Tests**: Review `deepiri/services/*/tests/` for existing test patterns
2. **CI/CD Workflows**: Study `deepiri/.github/workflows/` for automation pipelines
3. **Service Architecture**: Check `deepiri/docs/MICROSERVICES_SETUP.md` for service structure
4. **API Testing**: Review API testing approaches in existing tests
5. **Test Automation**: Understand test automation frameworks used
6. **Integration Tests**: Check `deepiri/python_backend/tests/integration/` for integration testing
**Unique Mission:** Microservice testing, CI/CD pipeline support, API validation. Microservice testing. Supports CI/CD pipeline. Automates test workflows and API validation. Integration testing for services. Test coverage improvement.
**Your Tasks:**
- Microservice testing
- Supports CI/CD pipeline
- Automates test workflows and API validation
- Integration testing for services
- Test coverage improvement

---

### Backend Intern 2 - Documentation
**Reports to:** Backend Lead
**Location:** `deepiri/services/*/docs/` & `deepiri/services/*/src/`
**Stack:** Documentation, API Documentation, Logging
**Start Here:**
- Services: `deepiri/services/`
**Unique Mission:** Writes request/response schemas, improves logging clarity, builds internal documentation.
**Your Tasks:**
- Writes request/response schemas
- Improves logging clarity
- Builds internal documentation and debug logs panel
- API documentation maintenance
- Code documentation and comments

---

### Backend Intern 3 - Performance Testing
**Reports to:** Backend Lead
**Location:** `deepiri/services/*/tests/performance/` & `deepiri/services/*/src/`
**Stack:** Performance Testing, Load Testing, Bug Fixes
**Start Here:**
1. **Service Architecture**: Review `deepiri/services/` to understand service structure
2. **Performance Tests**: Check `deepiri/services/*/tests/performance/` for existing performance tests
3. **API Endpoints**: Study service endpoints to understand what needs testing
4. **Load Testing Tools**: Familiarize with load testing tools used
5. **Performance Metrics**: Understand performance benchmarks and targets
6. **Bug Tracking**: Review bug reports to understand common performance issues
**Unique Mission:** Stress tests APIs, identifies slow endpoints, backend bug fixing. Stress tests APIs. Identifies slow endpoints, timing the requests, then if its too late we need to improve algorithm. Backend bug fixing. Performance reports. Load testing and optimization.
**Your Tasks:**
- Stress tests APIs
- Identifies slow endpoints
- Backend bug fixing
- Performance reports
- Load testing and optimization

---

## FRONTEND & UI TEAM

### Frontend Lead
**Reports to:** Product Lead
**Location:** `deepiri/frontend/`
**Stack:** React, TypeScript, Vite, Tailwind CSS, UX/UI Design
**Start Here:**
- Frontend: `deepiri/frontend/`
- App: `deepiri/frontend/src/App.jsx`
**Unique Mission:** Supervises web/frontend architecture, design consistency, and integration of UI with backend and cloud AI services. Reviews and merges code for frontend team.
**Your Tasks:**
- Supervises web/frontend architecture (React 18 + Vite)
- Design consistency across web and native desktop app
- Integration of UI with backend and cloud AI services
- UI theme direction for both web + native desktop app
- Review and merge code from Frontend Engineers
- Establish frontend coding standards
- Coordinate with Backend Lead on API integration
- Ensure responsive design and accessibility
**Files to Review:**
- `deepiri/frontend/src/App.jsx`
- `deepiri/frontend/src/components/`
- `deepiri/frontend/src/pages/`

---

### Graphic Designer
**Reports to:** Product Lead
**Location:** `deepiri/frontend/src/assets/` & `deepiri/frontend/public/`
**Stack:** Design Tools (Figma, Adobe), SVG, Branding
**Start Here:**
- Assets: `deepiri/frontend/src/assets/`
- Public: `deepiri/frontend/public/`
**Unique Mission:** Logo Design, Branding, Visual Identity.
**Your Tasks:**
- Logo design and brand identity
- Visual branding guidelines
- UI/UX design mockups
- Design system and style guide
- Icon and asset creation
- Brand consistency across platforms

---

### Frontend Engineer 1 - Core UI Foundation
**Reports to:** Frontend Lead
**Location:** `deepiri/frontend/src/pages/` & `deepiri/frontend/src/components/`
**Stack:** React, TypeScript, Firebase, Forms, Dashboards
**Start Here:**
- Pages: `deepiri/frontend/src/pages/`
- Components: `deepiri/frontend/src/components/`
**Unique Mission:** Builds pages, dashboards, forms, authentication flows for web app.
**Your Tasks:**
- Builds pages, dashboards, forms
- Authentication flows for web app
- UI foundations that the other engineers build on
- Core React components and layouts
- Routing and navigation
- Form validation and error handling

---

### Frontend Engineer 2 - AI Visualization
**Reports to:** Frontend Lead
**Location:** `deepiri/frontend/src/components/charts/` & `deepiri/frontend/src/pages/analytics/`
**Stack:** React, TypeScript, Chart.js, D3.js, Data Visualization
**Start Here:**
1. **Analytics Pages**: Review `deepiri/frontend/src/pages/analytics/` for existing analytics UI
2. **Chart Components**: Study `deepiri/frontend/src/components/charts/` for visualization components
3. **AI Service Integration**: Check how AI responses are visualized in the frontend
4. **Real-Time Updates**: Understand WebSocket integration for live AI feedback
5. **Multimodal Rendering**: Review how text, images, and code are displayed
6. **Chart Libraries**: Familiarize with Chart.js and D3.js usage in the codebase
**Unique Mission:** AI reasoning visualization, advanced charting, multimodal rendering.
**Your Tasks:**
- AI reasoning visualization
- Advanced charting for analytics
- Multimodal rendering (text, images, code)
- Interactive charts for analytics tools
- Real-time AI response visualization
- Model output display components

---

### Frontend Engineer 3 - Gamification UI
**Reports to:** Frontend Lead
**Location:** `deepiri/frontend/src/components/gamification/`
**Stack:** React, TypeScript, CSS Animations, Gamification UI
**Start Here:**
1. **Gamification Components**: Review `deepiri/frontend/src/components/gamification/` for existing UI
2. **Gamification Service**: Study `deepiri/services/gamification-service/` to understand backend API
3. **Badge System**: Check badge and achievement UI implementations
4. **Progress Visualization**: Review progress bars, XP displays, and streak tracking
5. **Animation Patterns**: Study CSS animation patterns used in the codebase
6. **Cross-Platform Components**: Understand how components work for both web and desktop UI
**Unique Mission:** Badges, animated avatars, progress bars, challenge animations.
**Your Tasks:**
- Badges and achievement UI
- Animated avatars
- Progress bars and XP visualization
- Challenge animations
- Cross-platform gamification components for web + desktop UI frameworks
- Streak tracking UI
- Reward animations

---

### Frontend Engineer 4 - Performance & PWA
**Reports to:** Frontend Lead
**Location:** `deepiri/frontend/` (Performance & PWA)
**Stack:** React, TypeScript, PWA, Performance Optimization, Service Workers
**Start Here:**
1. **Frontend Root**: Review `deepiri/frontend/` directory structure
2. **Vite Config**: Study `deepiri/frontend/vite.config.js` for build configuration
3. **Service Workers**: Check `deepiri/frontend/public/service-worker.js` (if exists) for PWA setup
4. **Bundle Analysis**: Review current bundle size and code splitting strategies
5. **Performance Metrics**: Understand current performance bottlenecks
6. **PWA Manifest**: Check `deepiri/frontend/public/manifest.json` for PWA configuration
7. **Native Desktop Bridge**: Review how web UI patterns bridge to native desktop app
**Unique Mission:** SPA optimization, PWA support, preloading strategies, offline-first UI cache.
**Your Tasks:**
- SPA optimization (React performance)
- PWA support for mobile
- Preloading strategies
- Bridges web UI patterns with native desktop application frontend
- Offline-first UI cache
- Code splitting and lazy loading
- Bundle size optimization

---

### Frontend Intern 1
**Reports to:** Frontend Lead
**Location:** `deepiri/frontend/src/components/` & `deepiri/frontend/tests/`
**Stack:** React, Testing Library, Jest, Component Development
**Start Here:**
1. **Component Library**: Review `deepiri/frontend/src/components/` to understand component structure
2. **Test Suite**: Study `deepiri/frontend/tests/` for testing patterns
3. **React Testing Library**: Familiarize with testing utilities used in the codebase
4. **Component Patterns**: Review existing component patterns and best practices
5. **Accessibility**: Check accessibility standards followed in components
6. **Bug Fixes**: Review recent bug reports to understand common issues
**Unique Mission:** Component polish, UI tests, bug fixes, learns the architecture.
**Your Tasks:**
- Component polish and refinement
- UI tests (Jest, React Testing Library)
- Bug fixes and small improvements
- Learns the architecture and contributes to smaller UI pieces
- Accessibility improvements
- Cross-browser testing

---

## SECURITY, SUPPORT & QA TEAM

### IT Lead
**Reports to:** Founder
**Location:** `deepiri/infrastructure/security/` & `deepiri/services/auth-service/`
**Stack:** Security Architecture, Network Defense, Cloud Security, Secure Microservices
**Start Here:**
- Infrastructure: `deepiri/infrastructure/`
- Auth service: `deepiri/services/auth-service/`
**Unique Mission:** Infrastructure support, organizational tech support, Network defense, secure microservices, cloud security.
**Your Tasks:**
- Infrastructure support for development and production
- Organizational tech support for employees
- Network defense and security monitoring
- Secure microservices architecture
- Cloud security and compliance
- Security incident response
- Access control and identity management
- Security policy enforcement

---

### IT Internal Support
**Reports to:** IT Lead
**Location:** `deepiri/docs/internal/` & `deepiri/scripts/onboarding/`
**Stack:** Internal Tools, Documentation, Onboarding Systems
**Start Here:**
- Docs: `deepiri/docs/`
**Unique Mission:** Employee tech support, onboarding/offboarding, software/hardware provisioning.
**Your Tasks:**
- Employee tech support
- Employee onboarding/offboarding
- Software/hardware provisioning
- Organizational tech support
- Development environment setup
- IT asset management

---

### IT External Support
**Reports to:** IT Lead
**Location:** `deepiri/docs/user/` & `deepiri/frontend/src/pages/support/`
**Stack:** User Support, Documentation, Help Systems
**Start Here:**
- Docs: `deepiri/docs/`
- Frontend: `deepiri/frontend/src/pages/`
**Unique Mission:** User tech support for Deepiri platform users.
**Your Tasks:**
- User tech support
- Customer service for technical issues
- User onboarding assistance
- Bug report triage and escalation
- User documentation and help guides

---

### Security Operations/ Support Engineer 1
**Reports to:** IT Lead / Founder
**Location:** `deepiri/infrastructure/security/` & `deepiri/scripts/security/`
**Stack:** Security Monitoring, Resource Management, Vulnerability Assessment
**Start Here:**
- Infrastructure: `deepiri/infrastructure/security/`
**Unique Mission:** Resource monitoring (Github, Discord), security operations.
**Your Tasks:**
- Resource monitoring (Github, Discord)
- Security monitoring and alerting
- Vulnerability scanning
- Security incident investigation
- Access control monitoring

---

### Security Operations/ Support Engineer 2
**Reports to:** IT Lead
**Location:** `deepiri/infrastructure/security/` & `deepiri/scripts/security/`
**Stack:** Security Monitoring, Resource Management, Vulnerability Assessment
**Start Here:**
- Infrastructure: `deepiri/infrastructure/security/`
**Unique Mission:** Resource monitoring (Github, Discord), security operations.
**Your Tasks:**
- Resource monitoring (Github, Discord)
- Security monitoring and alerting
- Vulnerability scanning
- Security incident investigation
- Access control monitoring

---

### Security Operations Analyst
**Reports to:** IT Lead
**Location:** `deepiri/infrastructure/security/` & `deepiri/scripts/security/`
**Stack:** Security Scanning, Dependency Management, Vulnerability Assessment
**Start Here:**
- Infrastructure: `deepiri/infrastructure/security/`
**Unique Mission:** Resource monitoring (Github, Discord), checking cloud security, platform security, checking Dependabot alerts.
**Your Tasks:**
- Resource monitoring (Github, Discord)
- Checking cloud security configurations
- Platform security assessment
- Checking Dependabot alerts for dependency files
- Security vulnerability analysis
- Security compliance checking
- Dependency security scanning

---

### QA Lead
**Reports to:** Product Lead
**Location:** `deepiri/tests/` & `deepiri/qa/`
**Stack:** Test Planning, Integration Testing, Test Strategy
**Start Here:**
- Tests: `deepiri/tests/`
- QA: `deepiri/qa/` (create)
**Unique Mission:** Ensure product quality across both web and native IDE, guiding QA engineers in testing strategy and coverage. Reviews and merges code for QA team.
**Your Tasks:**
- Create test plans for new features and releases
- Coordinate integration testing between frontend, backend, and AI systems
- Oversee regression testing to maintain system stability
- Define QA standards and testing protocols
- Act as primary QA liaison with Product Lead
- Review and merge code for QA team and other teams
- Establish testing automation strategy
- Coordinate with all teams on quality standards

---

### QA Engineer 1 - Manual Testing
**Reports to:** QA Lead
**Location:** `deepiri/tests/manual/` & `deepiri/qa/manual/`
**Stack:** Manual Testing, User Acceptance Testing, Test Cases
**Start Here:**
- Tests: `deepiri/tests/`
**Unique Mission:** Test features from a user perspective to ensure functionality and usability.
**Your Tasks:**
- Execute manual test cases across web and native IDE
- Perform user acceptance testing (UAT) on new releases
- Verify bug fixes and report anomalies to QA Lead
- Provide feedback on user experience and workflow issues
- Validate AI agent output alignment with intended task guidance
- Test challenge generation and gamification flows
- Validate external integrations (Notion, Trello, GitHub)

---

### QA Engineer 2 - Automation
**Reports to:** QA Lead
**Location:** `deepiri/tests/automation/` & `deepiri/qa/automation/`
**Stack:** Automation Testing, API Testing, Selenium, Playwright, Test Reporting
**Start Here:**
- Tests: `deepiri/tests/`
**Unique Mission:** Ensure system reliability and backend robustness through automation.
**Your Tasks:**
- Design and maintain automated test scripts for backend APIs
- Perform API endpoint validation for web and native IDE
- Track metrics on automation coverage and bug trends
- Report testing results to QA Lead and coordinate with backend team
- Automate repetitive regression and integration tests
- API testing with Postman/Newman or similar tools
- End-to-end testing with Playwright/Cypress

---

### QA Intern 1
**Reports to:** QA Lead / Engineers
**Location:** `deepiri/tests/` & `deepiri/qa/`
**Stack:** Test Scripts, Bug Tracking, Basic QA Tasks
**Start Here:**
- Tests: `deepiri/tests/`
**Unique Mission:** Assist QA engineers with routine testing and documentation. KEEPS TRACK OF TESTING DOCUMENTATION.
**Your Tasks:**
- Write and maintain simple test scripts for manual testing
- Log, track, and document bugs in the tracking system
- Perform basic QA tasks such as cross-browser/device checks
- Support QA Engineer 1 in user acceptance testing
- Help maintain test case documentation
- **YOU KEEP TRACK OF THE TESTING DOCUMENTATION!**

---

### QA Intern 2
**Reports to:** QA Lead / Engineers
**Location:** `deepiri/tests/regression/` & `deepiri/qa/`
**Stack:** Regression Testing, Test Suite Maintenance, Environment Setup
**Start Here:**
- Tests: `deepiri/tests/`
**Unique Mission:** Support QA team in maintaining system stability and test environments.
**Your Tasks:**
- Maintain regression test suites for repeated releases
- Assist in setting up testing environments (web and native)
- Ensure test data consistency for repeated QA cycles
- Support QA Lead in executing integration regression runs
- Monitor environment health during automated test execution
- Test environment maintenance and cleanup

---

## DESKTOP IDE TEAM

### Desktop IDE Developers
**Location:** `desktop-ide-deepiri/` (at project root, same level as deepiri/)
**Stack:** Tauri, Rust, React, TypeScript, SQLite, Local LLM
**Start Here:**
- Desktop IDE: `desktop-ide-deepiri/README.md`
- Tauri backend: `desktop-ide-deepiri/src-tauri/src/`
- React frontend: `desktop-ide-deepiri/src/renderer/`
**Your Tasks:**
- Desktop IDE development
- Tauri backend integration
- React frontend components
- Local LLM integration
- Desktop-specific features
**Key Files:**
- `desktop-ide-deepiri/src-tauri/src/main.rs`
- `desktop-ide-deepiri/src/renderer/App.jsx`
- `desktop-ide-deepiri/src/renderer/services/aiService.js`
- `desktop-ide-deepiri/src/renderer/components/`

---

## QUICK START CHECKLIST

1. **Find your role** in this document (Ctrl+F)
2. **Check your "Location"** - that's where you'll be working
3. **Review your "Stack"** - technologies you'll use
4. **Start with "Start Here"** files
5. **Work on "Your Tasks"** and "Files to Work On"
6. **Ask questions** in team channels if stuck

---

## IMPORTANT LINKS

- **Main README:** `deepiri/README.md`
- **Microservices Architecture:** `deepiri/docs/MICROSERVICES_SETUP.md` - **READ THIS!**
- **Getting Started:** `deepiri/GETTING_STARTED.md`
- **Environment Variables:** `deepiri/ENVIRONMENT_VARIABLES.md`
- **Team Onboarding:** `deepiri/docs/*_TEAM_ONBOARDING.md`
- **AI Team Onboarding:** `deepiri/docs/AI_TEAM_ONBOARDING.md`
- **Backend Team Onboarding:** `deepiri/docs/BACKEND_TEAM_ONBOARDING.md`
- **Frontend Team Onboarding:** `deepiri/docs/FRONTEND_TEAM_ONBOARDING.md`
- **Desktop IDE README:** `desktop-ide-deepiri/README.md` (at project root)

## MICROSERVICES ARCHITECTURE NOTES

**All requests go through API Gateway (Port 5000):**
- Frontend connects to: `http://localhost:5000/api/*`
- API Gateway routes to appropriate microservice
- Each service runs on its own port (5001-5008)
- Python AI Service runs on port 8000

**Service Ports:**
- API Gateway: 5000
- User Service: 5001
- Task Service: 5002
- Gamification Service: 5003
- Analytics Service: 5004
- Notification Service: 5005
- Integration Service: 5006
- Challenge Service: 5007
- WebSocket Service: 5008
- Python AI Service: 8000

---

**Last Updated:** 2024
**Questions?** Contact your team lead or check team-specific READMEs.
