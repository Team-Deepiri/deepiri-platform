# FIND YOUR TASKS - Deepiri Team Guide

**Quick Navigation:** Use Ctrl+F to find your role

---

## AI TEAM

### AI Research Lead
**Location:** `deepiri/python_backend/train/`
**Stack:** Python, PyTorch, Transformers, MLflow, W&B, Jupyter
**Start Here:**
- Review: `deepiri/python_backend/train/README.md`
- Experiment tracking: `deepiri/python_backend/train/infrastructure/experiment_tracker.py`
- Research templates: `deepiri/python_backend/train/experiments/research_experiment_template.py`
**Your Tasks:**
- Oversee LLM development and model orchestration
- Review experiment results from research scientists
- Coordinate cutting-edge AI integration
- Guide fine-tuning strategies
- Review challenge generation algorithms

---

### AI Research Scientist 1 
**Location:** `deepiri/python_backend/train/experiments/`
**Stack:** Python, PyTorch, Transformers, Novel Architectures (Mamba, MoE), Custom Training Loops
**Start Here:**
- Template: `deepiri/python_backend/train/experiments/research_experiment_template.py`
- Notebooks: `deepiri/python_backend/train/notebooks/`
**Your Tasks:**
- Research novel neural architectures for gamification
- Develop new training methodologies for task understanding
- Experiment with Mamba, MoE architectures
- Research alternative approaches to transformer-based systems
- Explore neuro-symbolic AI: `deepiri/python_backend/app/services/neuro_symbolic_challenge.py`
- Investigate new optimization algorithms beyond Adam/AdamW
**Files to Create:**
- `deepiri/python_backend/train/experiments/mamba_architecture.py`
- `deepiri/python_backend/train/experiments/moe_gamification.py`
- `deepiri/python_backend/train/experiments/neuro_symbolic_experiments.py`

---

### AI Research Scientist 2
**Location:** `deepiri/python_backend/train/experiments/multimodal/`
**Stack:** Python, PyTorch, Multimodal Models (CLIP, BLIP), Vision Transformers, Audio Processing
**Start Here:**
- Multimodal service: `deepiri/python_backend/app/services/multimodal_understanding.py`
**Your Tasks:**
- Research multimodal fusion techniques for task understanding
- Explore reasoning frameworks beyond chain-of-thought
- Investigate code understanding and generation
- Research visual reasoning for creative task gamification
- Experiment with audio/visual multimodal challenge generation
- Explore graph neural networks: `deepiri/python_backend/train/experiments/gnn_task_relationships.py`
**Files to Create:**
- `deepiri/python_backend/train/experiments/multimodal_fusion.py`
- `deepiri/python_backend/train/experiments/visual_reasoning.py`
- `deepiri/python_backend/train/experiments/graph_neural_networks.py`

---

### AI Research Scientist 3
**Location:** `deepiri/python_backend/train/experiments/compression/`
**Stack:** Python, PyTorch, Quantization (GPTQ, QLoRA), Pruning, Distillation, ONNX, TensorRT
**Start Here:**
- LoRA training: `deepiri/python_backend/train/infrastructure/lora_training.py`
- Model compression experiments
**Your Tasks:**
- Research new model compression techniques
- Explore alternative local model architectures
- Investigate federated learning: `deepiri/python_backend/train/experiments/federated_learning.py`
- Research energy-efficient model architectures for mobile
- Experiment with quantization and pruning methods
- Explore sparse training paradigms
**Files to Create:**
- `deepiri/python_backend/train/experiments/quantization_methods.py`
- `deepiri/python_backend/train/experiments/pruning_techniques.py`
- `deepiri/python_backend/train/experiments/sparse_training.py`
- `deepiri/python_backend/train/experiments/federated_learning.py`

---

### AI Systems Lead 
**Location:** `deepiri/python_backend/app/services/` & `deepiri/python_backend/train/pipelines/`
**Stack:** Python, FastAPI, Docker, Kubernetes, MLflow, Model Deployment
**Start Here:**
- Services: `deepiri/python_backend/app/services/`
- Training pipelines: `deepiri/python_backend/train/pipelines/`
- Main app: `deepiri/python_backend/app/main.py`
**Your Tasks:**
- Model deployment infrastructure
- Inference optimization
- Training pipeline management
- Coordinate with AI Systems Engineers

---

### AI Systems Engineer 1
**Location:** `deepiri/python_backend/app/services/` (Real-time AI)
**Stack:** Python, FastAPI, OpenAI API, Anthropic API, AsyncIO, WebSockets, NumPy
**Start Here:**
- Advanced task parser: `deepiri/python_backend/app/services/advanced_task_parser.py` - NEW
- Adaptive challenge generator: `deepiri/python_backend/app/services/adaptive_challenge_generator.py` - NEW
- Challenge generator: `deepiri/python_backend/app/services/challenge_generator.py`
- Task classifier: `deepiri/python_backend/app/services/task_classifier.py`
- Hybrid AI: `deepiri/python_backend/app/services/hybrid_ai_service.py`
**Your Tasks:**
- Real-time challenge generation optimization with RL-based adaptation
- AI model orchestration for advanced services
- Prompt engineering for advanced task parsing and challenge generation
- API integration (OpenAI, Anthropic, HuggingFace)
- Response caching and optimization
- Integration of advanced services with existing endpoints
**Files to Work On:**
- `deepiri/python_backend/app/services/advanced_task_parser.py` - NEW: Advanced parsing
- `deepiri/python_backend/app/services/adaptive_challenge_generator.py` - NEW: Adaptive generation
- `deepiri/python_backend/app/services/challenge_generator.py` - Standard generation
- `deepiri/python_backend/app/services/hybrid_ai_service.py` - Hybrid AI
- `deepiri/python_backend/app/routes/challenge.py` - API routes (update for new services)

---

### AI Systems Engineer 2
**Location:** `deepiri/python_backend/app/services/` (Real-time AI)
**Stack:** Python, FastAPI, OpenAI API, Anthropic API, AsyncIO, WebSockets, NumPy
**Start Here:**
- Advanced task parser: `deepiri/python_backend/app/services/advanced_task_parser.py` - NEW
- Adaptive challenge generator: `deepiri/python_backend/app/services/adaptive_challenge_generator.py` - NEW
- Context-aware adaptation: `deepiri/python_backend/app/services/context_aware_adaptation.py`
**Your Tasks:**
- Real-time challenge generation optimization with engagement prediction
- AI model orchestration for personalization
- Prompt engineering for personalization and context adaptation
- Multi-model fallback strategies
- Response streaming and real-time updates
- Integration of adaptive difficulty and reward systems
**Files to Work On:**
- `deepiri/python_backend/app/services/adaptive_challenge_generator.py` - NEW: Engagement prediction
- `deepiri/python_backend/app/services/context_aware_adaptation.py` - Context adaptation
- `deepiri/python_backend/app/services/personalization_service.py` (create if needed)
- `deepiri/python_backend/app/routes/personalization.py` - Personalization routes

---

### AI Systems Engineer 3
**Location:** `deepiri/python_backend/train/pipelines/` & `deepiri/python_backend/mlops/`
**Stack:** Python, PyTorch, Distributed Training (DeepSpeed, Ray), Kubernetes, MLflow
**Start Here:**
- Training pipeline: `deepiri/python_backend/train/pipelines/full_training_pipeline.py`
- Distributed training: `deepiri/python_backend/train/pipelines/distributed_training.py`
- MLOps: `deepiri/python_backend/mlops/`
**Your Tasks:**
- Training pipeline infrastructure
- Distributed computing for model training
- Model deployment automation
- GPU resource management
- Training job scheduling
**Files to Work On:**
- `deepiri/python_backend/train/pipelines/distributed_training.py`
- `deepiri/python_backend/mlops/ci/training_pipeline.yml`
- `deepiri/python_backend/mlops/deployment/model_deployment.py` (create)

---

### AI Systems Engineer 4
**Location:** `deepiri/python_backend/train/pipelines/` & `deepiri/python_backend/mlops/`
**Stack:** Python, PyTorch, Distributed Training, Kubernetes, CI/CD, Model Registry
**Start Here:**
- Same as AI Systems Engineer 3
**Your Tasks:**
- Training pipeline infrastructure
- Distributed computing optimization
- Model versioning and registry
- Automated model testing
- Production deployment pipelines
**Files to Work On:**
- `deepiri/python_backend/mlops/registry/model_registry.py` (create)
- `deepiri/python_backend/mlops/ci/model_testing.yml` (create)
- `deepiri/python_backend/train/pipelines/ml_training_pipeline.py`

---

### ML Engineer 1
**Location:** `deepiri/python_backend/train/scripts/` (RL & Bandits)
**Stack:** Python, PyTorch, Reinforcement Learning (RLlib, Stable-Baselines3), Multi-Armed Bandits
**Start Here:**
- Bandit training: `deepiri/python_backend/train/pipelines/bandit_training.py`
- Bandit service: `deepiri/python_backend/app/services/bandit_service.py` (create if needed)
**Your Tasks:**
- Train multi-armed bandit models for challenge selection
- Train policy networks for personalized challenge generation
- Train value networks for user engagement prediction
- Train actor-critic models for real-time difficulty adjustment
**Files to Create:**
- `deepiri/python_backend/train/scripts/train_policy_network.py`
- `deepiri/python_backend/train/scripts/train_value_network.py`
- `deepiri/python_backend/train/scripts/train_actor_critic.py`
- `deepiri/python_backend/app/services/bandit_service.py`

---

### ML Engineer 2 
**Location:** `deepiri/python_backend/train/scripts/` (Transformers & Fine-tuning)
**Stack:** Python, PyTorch, Transformers, PEFT/LoRA, Quantization (bitsandbytes, GPTQ)
**Start Here:**
- Task classifier training: `deepiri/python_backend/train/scripts/train_task_classifier.py`
- Transformer training: `deepiri/python_backend/train/scripts/train_transformer_classifier.py`
- LoRA training: `deepiri/python_backend/train/infrastructure/lora_training.py`
**Your Tasks:**
- Train and fine-tune transformer models for task classification
- Train teacher-student models for knowledge distillation
- Train quantized models for mobile deployment
- Train efficientNet-style architectures for edge devices
- Train pruned models for faster inference
**Files to Work On:**
- `deepiri/python_backend/train/scripts/train_task_classifier.py`
- `deepiri/python_backend/train/scripts/train_transformer_classifier.py`
- `deepiri/python_backend/train/scripts/train_teacher_student.py` (create)
- `deepiri/python_backend/train/scripts/train_quantized_model.py` (create)

---

### ML Engineer 3
**Location:** `deepiri/python_backend/train/scripts/` (Lightweight & Temporal Models)
**Stack:** Python, PyTorch, Lightweight Models (MobileNet, EfficientNet), Temporal Models (LSTM, GRU, Transformers)
**Start Here:**
- Challenge generator training: `deepiri/python_backend/train/scripts/train_challenge_generator.py`
- Personalization training: `deepiri/python_backend/train/scripts/train_personalization_model.py`
**Your Tasks:**
- Train lightweight models for offline challenge generation
- Train temporal models for user behavior prediction
- Train ensemble models for challenge quality scoring
- Train on-device recommendation models
- Train federated learning models for privacy preservation
**Files to Create:**
- `deepiri/python_backend/train/scripts/train_lightweight_challenge_generator.py`
- `deepiri/python_backend/train/scripts/train_temporal_behavior_model.py`
- `deepiri/python_backend/train/scripts/train_ensemble_scoring.py`
- `deepiri/python_backend/train/scripts/train_on_device_recommendation.py`

---

### MLOps Engineer 1
**Location:** `deepiri/python_backend/mlops/ci/` & `deepiri/python_backend/mlops/deployment/`
**Stack:** Python, CI/CD (GitHub Actions, GitLab CI), Kubernetes, MLflow, Docker, Prometheus
**Start Here:**
- **Onboarding Guide**: `deepiri/docs/MLOPS_TEAM_ONBOARDING.md` (READ THIS FIRST!)
- **CI/CD Pipeline**: `deepiri/python_backend/mlops/ci/model_ci_pipeline.py`
- **Deployment**: `deepiri/python_backend/mlops/deployment/deployment_automation.py`
- **Model Registry**: `deepiri/python_backend/mlops/registry/model_registry.py`
- **MLOps README**: `deepiri/python_backend/mlops/README.md`
- **Setup Script**: `deepiri/python_backend/mlops/scripts/setup_mlops_environment.sh`
**Your Tasks:**
- **CI/CD for AI models**: Automate model updates and monitor engagement metrics
- **Model versioning and registry**: Manage model lifecycle with semantic versioning
- **Cloud GPU management**: Optimize GPU resource allocation
- **Automated training pipelines**: End-to-end training automation
- **Model deployment automation**: Canary, blue-green, and A/B testing deployments
- **A/B testing framework**: Setup and manage A/B tests for challenge effectiveness
**Files to Work On:**
- `deepiri/python_backend/mlops/ci/model_ci_pipeline.py` - Main CI/CD pipeline
- `deepiri/python_backend/mlops/deployment/deployment_automation.py` - Deployment strategies
- `deepiri/python_backend/mlops/registry/model_registry.py` - Model registry
- `deepiri/python_backend/mlops/scripts/run_ci_pipeline.sh` - CI/CD automation
- `deepiri/python_backend/mlops/scripts/deploy_model.sh` - Deployment script
**Files to Create:**
- `deepiri/python_backend/mlops/ci/github_actions.yml` - GitHub Actions workflow
- `deepiri/python_backend/mlops/deployment/kubernetes_deployment.yaml` - K8s manifests
- `deepiri/python_backend/mlops/gpu/gpu_manager.py` - GPU resource management

---

### MLOps Engineer 2 
**Location:** `deepiri/python_backend/mlops/monitoring/` & `deepiri/python_backend/mlops/optimization/`
**Stack:** Python, Prometheus, Grafana, MLflow, Performance Profiling, Alerting
**Start Here:**
- **Onboarding Guide**: `deepiri/docs/MLOPS_TEAM_ONBOARDING.md` (READ THIS FIRST!)
- **Model Monitoring**: `deepiri/python_backend/mlops/monitoring/model_monitor.py`
- **Docker Setup**: `deepiri/python_backend/mlops/docker/docker-compose.mlops.yml`
- **MLOps README**: `deepiri/python_backend/mlops/README.md`
**Your Tasks:**
- **Performance monitoring**: Track accuracy, latency, throughput, error rates
- **Model drift detection**: Data drift and prediction drift monitoring
- **Deployment automation**: Monitor deployments and automate rollbacks
- **Resource optimization**: GPU utilization, model quantization, caching
- **Inference latency optimization**: Model compression, batching, caching
- **Alerting systems**: Setup alerts for performance degradation and drift
- **Monitoring dashboards**: Create Grafana dashboards for model metrics
**Files to Work On:**
- `deepiri/python_backend/mlops/monitoring/model_monitor.py` - Main monitoring service
- `deepiri/python_backend/mlops/scripts/monitor_model.sh` - Monitoring script
- `deepiri/python_backend/mlops/docker/docker-compose.mlops.yml` - Monitoring stack
**Files to Create:**
- `deepiri/python_backend/mlops/monitoring/dashboards/` - Grafana dashboard configs
- `deepiri/python_backend/mlops/monitoring/alerts/` - Alert configurations
- `deepiri/python_backend/mlops/monitoring/drift_detection.py` - Advanced drift detection
- `deepiri/python_backend/mlops/monitoring/performance_metrics.py` - Performance tracking
- `deepiri/python_backend/mlops/optimization/inference_optimization.py` - Inference optimization
- `deepiri/python_backend/mlops/optimization/resource_optimizer.py` - Resource optimization

---

### Data Engineer 1
**Location:** `deepiri/python_backend/train/data/` & `deepiri/python_backend/app/services/analytics/`
**Stack:** Python, Pandas, NumPy, Apache Kafka, Real-time Processing, Feature Engineering
**Start Here:**
- Data collection: `deepiri/python_backend/train/pipelines/data_collection_pipeline.py`
- Dataset prep: `deepiri/python_backend/train/data/prepare_dataset.py`
**Your Tasks:**
- User behavior pipelines
- Challenge performance analytics
- Real-time feature engineering
- Data streaming pipelines
- Event processing
**Files to Create:**
- `deepiri/python_backend/train/data/user_behavior_pipeline.py`
- `deepiri/python_backend/train/data/challenge_analytics_pipeline.py`
- `deepiri/python_backend/app/services/analytics/real_time_features.py`
- `deepiri/python_backend/app/services/analytics/event_processor.py`

---

### Data Engineer 2
**Location:** `deepiri/python_backend/train/data/` (Data Quality & Privacy)
**Stack:** Python, Pandas, Data Validation, Privacy Tools (Differential Privacy, PII Detection)
**Start Here:**
- Dataset prep: `deepiri/python_backend/train/data/prepare_dataset.py`
- Data collection: `deepiri/python_backend/train/pipelines/data_collection_pipeline.py`
**Your Tasks:**
- Training data curation
- Data quality assurance
- Privacy and anonymization
- PII detection and redaction
- Data validation pipelines
**Files to Create:**
- `deepiri/python_backend/train/data/data_curation.py`
- `deepiri/python_backend/train/data/data_quality.py`
- `deepiri/python_backend/train/data/privacy_anonymization.py`
- `deepiri/python_backend/train/data/pii_detection.py`
- `deepiri/python_backend/train/data/data_validation.py`

---

### AI Systems Intern 1
**Location:** `deepiri/python_backend/train/scripts/` & `deepiri/python_backend/tests/ai/`
**Stack:** Python, PyTorch, Pytest, Testing Frameworks
**Start Here:**
- Test suite: `deepiri/python_backend/tests/ai/`
- Training scripts: `deepiri/python_backend/train/scripts/`
**Your Tasks:**
- Support model training
- Write test cases for AI services
- Documentation for training scripts
- Test data preparation
**Files to Work On:**
- `deepiri/python_backend/tests/ai/test_task_classifier.py`
- `deepiri/python_backend/tests/ai/test_challenge_generator.py`
- `deepiri/python_backend/train/scripts/README.md` (create/update)

---

### AI Systems Intern 2
**Location:** `desktop-ide-deepiri/src-tauri/src/` (Mobile/Edge AI)
**Stack:** Rust, ONNX Runtime, Quantized Models, Mobile Deployment
**Start Here:**
- Local LLM: `desktop-ide-deepiri/src-tauri/src/local_llm.rs`
- Tauri backend: `desktop-ide-deepiri/src-tauri/src/main.rs`
**Your Tasks:**
- Mobile AI testing
- Edge deployment experiments
- Performance analysis for on-device models
- Quantized model integration
- Local inference optimization
**Files to Work On:**
- `desktop-ide-deepiri/src-tauri/src/local_llm.rs`
- `desktop-ide-deepiri/src-tauri/src/commands.rs`
- `desktop-ide-deepiri/tests/edge_ai_tests.rs` (create)

---

### AI Systems Intern 3
**Location:** `deepiri/python_backend/train/data/`
**Stack:** Python, Pandas, Data Processing, ETL Pipelines
**Start Here:**
- Dataset prep: `deepiri/python_backend/train/data/prepare_dataset.py`
- Data collection: `deepiri/python_backend/train/pipelines/data_collection_pipeline.py`
**Your Tasks:**
- Data preprocessing
- Pipeline support
- Dataset preparation
- Data cleaning scripts
- ETL pipeline maintenance
**Files to Work On:**
- `deepiri/python_backend/train/data/prepare_dataset.py`
- `deepiri/python_backend/train/data/data_cleaning.py` (create)
- `deepiri/python_backend/train/data/etl_pipeline.py` (create)

---

### AI Systems Intern 4
**Location:** `deepiri/python_backend/tests/ai/benchmarks/` & `deepiri/python_backend/train/scripts/`
**Stack:** Python, Pytest, Benchmarking Tools, Performance Profiling
**Start Here:**
- Benchmarks: `deepiri/python_backend/tests/ai/benchmarks/benchmark_classifier.py`
- Evaluation: `deepiri/python_backend/train/scripts/evaluate_model.py`
**Your Tasks:**
- Benchmarking model performance
- Model evaluation scripts
- Quality metrics calculation
- Performance profiling
- Test suite maintenance
**Files to Work On:**
- `deepiri/python_backend/tests/ai/benchmarks/benchmark_classifier.py`
- `deepiri/python_backend/train/scripts/evaluate_model.py`
- `deepiri/python_backend/tests/ai/benchmarks/benchmark_generator.py` (create)
- `deepiri/python_backend/train/scripts/quality_metrics.py` (create)

---

### AI Systems Intern 5
**Location:** `deepiri/python_backend/docs/` & `deepiri/python_backend/tests/`
**Stack:** Python, Documentation Tools, Testing, Code Quality
**Start Here:**
- Tests: `deepiri/python_backend/tests/`
- READMEs: `deepiri/python_backend/train/README.md`
**Your Tasks:**
- Documentation for AI services
- Code quality checks
- Testing scripts
- API documentation
- Code review support
**Files to Create:**
- `deepiri/python_backend/docs/ai_services.md`
- `deepiri/python_backend/docs/training_guide.md`
- `deepiri/python_backend/tests/README.md`
- `deepiri/python_backend/.pre-commit-config.yaml` (create)

---

### AI Systems Intern 6
**Location:** `deepiri/python_backend/tests/ai/` & `deepiri/python_backend/train/experiments/`
**Stack:** Python, Pytest, Simulation Frameworks, Validation Tools
**Start Here:**
- AI tests: `deepiri/python_backend/tests/ai/`
- Integration tests: `deepiri/python_backend/tests/integration/`
**Your Tasks:**
- QA Agent testing
- Simulation environments
- Validation scripts
- End-to-end AI testing
- Test automation
**Files to Create:**
- `deepiri/python_backend/tests/ai/test_qa_agent.py`
- `deepiri/python_backend/train/experiments/simulation_env.py`
- `deepiri/python_backend/tests/integration/test_ai_pipeline.py`

---

## MICROSERVICES / BACKEND TEAM

### Backend Lead
**Location:** `deepiri/services/` & `deepiri/python_backend/app/`
**Stack:** Node.js, Fastify, Python, FastAPI, MongoDB, Redis, Microservices Architecture
**Start Here:**
- Architecture: `deepiri/MICROSERVICES_ARCHITECTURE.md`
- Services: `deepiri/services/`
- Python backend: `deepiri/python_backend/app/main.py`
**Your Tasks:**
- Oversee microservices architecture
- Coordinate APIs and database design
- Team coordination with AI systems
- Service communication patterns
- Architecture decisions

---

### Backend Engineer 1
**Location:** `deepiri/services/integration-service/`
**Stack:** Node.js, Fastify, OAuth2, REST APIs, Webhooks, External API Integration
**Start Here:**
- Integration service: `deepiri/services/integration-service/README.md`
**Your Tasks:**
- External Integrations: Notion/Trello/GitHub APIs
- OAuth flows
- Webhook management
- Data synchronization
**Files to Create:**
- `deepiri/services/integration-service/src/notion.js`
- `deepiri/services/integration-service/src/trello.js`
- `deepiri/services/integration-service/src/github.js`
- `deepiri/services/integration-service/src/oauth.js`
- `deepiri/services/integration-service/src/webhooks.js`

---

### Backend Engineer 2
**Location:** `deepiri/services/websocket-service/`
**Stack:** Node.js, Socket.IO, WebSockets, Real-time Systems, Redis Pub/Sub
**Start Here:**
- WebSocket service: `deepiri/services/websocket-service/README.md`
**Your Tasks:**
- Real-time Systems: WebSocket server
- Live challenge updates
- Multiplayer sessions
- Presence tracking
- Real-time notifications
**Files to Create:**
- `deepiri/services/websocket-service/src/server.js`
- `deepiri/services/websocket-service/src/challenge_updates.js`
- `deepiri/services/websocket-service/src/multiplayer.js`
- `deepiri/services/websocket-service/src/presence.js`

---

### Backend Engineer 3
**Location:** `deepiri/python_backend/app/routes/` & `deepiri/services/challenge-service/`
**Stack:** Python, FastAPI, Node.js, Fastify, AI Integration, State Management
**Start Here:**
- Challenge routes: `deepiri/python_backend/app/routes/challenge.py`
- Challenge service: `deepiri/services/challenge-service/`
- AI services: `deepiri/python_backend/app/services/`
**Your Tasks:**
- AI Integration: Python service communication
- Challenge state management
- Gamification rule engine
- AI response validation
- Service orchestration
**Files to Work On:**
- `deepiri/python_backend/app/routes/challenge.py`
- `deepiri/services/challenge-service/src/challenge_state.js`
- `deepiri/services/challenge-service/src/gamification_rules.js`
- `deepiri/services/challenge-service/src/ai_validator.js` (create)

---

### Backend Engineer 4
**Location:** `deepiri/services/*/src/database/` & `deepiri/python_backend/app/database/`
**Stack:** MongoDB, Redis, SQL, Database Optimization, Query Performance, Data Migrations
**Start Here:**
- Database models: `deepiri/python_backend/app/database/models.py`
- Database config: `deepiri/python_backend/app/config/database.py`
**Your Tasks:**
- Data & Performance: Database optimization
- Caching strategies
- Query performance
- Data migrations
- Backup systems
**Files to Create:**
- `deepiri/python_backend/app/database/optimization.py`
- `deepiri/python_backend/app/utils/cache.py`
- `deepiri/python_backend/app/database/migrations/` (create directory)
- `deepiri/services/*/src/database/backup.js` (create in each service)

---

### FullStack Engineer 1 (AI)
**Location:** `deepiri/frontend/src/pages/` & `deepiri/python_backend/app/routes/`
**Stack:** React, TypeScript, FastAPI, REST APIs, Real-time Updates
**Start Here:**
- Productivity chat: `deepiri/frontend/src/pages/ProductivityChat.jsx`
- Challenge routes: `deepiri/python_backend/app/routes/challenge.py`
**Your Tasks:**
- AI Challenge Interfaces: Challenge generation UI
- Real-time AI response handling
- Model output visualization
- AI service API integration
- Challenge completion flows
**Files to Create:**
- `deepiri/frontend/src/components/ChallengeGenerator.jsx`
- `deepiri/frontend/src/components/AIResponseViewer.jsx`
- `deepiri/frontend/src/components/ModelOutputVisualization.jsx`
- `deepiri/frontend/src/services/challengeApi.js`

---

### FullStack Engineer 2
**Location:** `deepiri/frontend/src/components/gamification/` & `deepiri/services/gamification-service/`
**Stack:** React, TypeScript, Socket.IO, Real-time Updates, Animations
**Start Here:**
- Gamification service: `deepiri/services/gamification-service/`
- Frontend components: `deepiri/frontend/src/components/`
**Your Tasks:**
- Gamification UI/UX Full-Stack:
  - Interactive progress tracking
  - Badge and achievement animations
  - Leaderboard real-time updates
  - Social features interface
  - Mobile-responsive gamification
**Files to Create:**
- `deepiri/frontend/src/components/gamification/ProgressTracker.jsx`
- `deepiri/frontend/src/components/gamification/BadgeAnimation.jsx`
- `deepiri/frontend/src/components/gamification/Leaderboard.jsx`
- `deepiri/frontend/src/components/gamification/SocialFeatures.jsx`
- `deepiri/services/gamification-service/src/realtime_updates.js`

---

### FullStack Engineer 3
**Location:** `deepiri/frontend/src/pages/integrations/` & `deepiri/services/integration-service/`
**Stack:** React, TypeScript, Node.js, OAuth2, REST APIs
**Start Here:**
- Integration service: `deepiri/services/integration-service/`
- Frontend: `deepiri/frontend/src/pages/`
**Your Tasks:**
- Integration Dashboard: External service UI
- OAuth flows
- Data sync monitoring
- Configuration interfaces
**Files to Create:**
- `deepiri/frontend/src/pages/integrations/Dashboard.jsx`
- `deepiri/frontend/src/components/integrations/OAuthFlow.jsx`
- `deepiri/frontend/src/components/integrations/SyncMonitor.jsx`
- `deepiri/frontend/src/components/integrations/ConfigInterface.jsx`

---

### FullStack Engineer 4
**Location:** `deepiri/frontend/src/pages/analytics/` & `deepiri/services/analytics-service/`
**Stack:** React, TypeScript, Chart.js/D3.js, FastAPI, Real-time Data
**Start Here:**
- Analytics service: `deepiri/services/analytics-service/`
- Frontend: `deepiri/frontend/src/pages/`
**Your Tasks:**
- Analytics & Insights Full-Stack:
  - Performance dashboard UI
  - Productivity visualization
  - Real-time analytics API
  - Data export features
  - Insight recommendation UI
**Files to Create:**
- `deepiri/frontend/src/pages/analytics/Dashboard.jsx`
- `deepiri/frontend/src/components/analytics/ProductivityChart.jsx`
- `deepiri/frontend/src/components/analytics/InsightRecommendations.jsx`
- `deepiri/services/analytics-service/src/realtime_analytics.js`
- `deepiri/services/analytics-service/src/data_export.js`

---

### Systems Architect 1 
**Location:** `deepiri/services/` & `deepiri/MICROSERVICES_ARCHITECTURE.md`
**Stack:** System Design, Microservices Patterns, API Gateway, Service Mesh
**Start Here:**
- Architecture doc: `deepiri/MICROSERVICES_ARCHITECTURE.md`
- API Gateway: `deepiri/services/api-gateway/`
**Your Tasks:**
- Core System Architecture: Microservices design
- Scalability planning
- Cross-service communication
- Service discovery
- Load balancing
**Files to Create:**
- `deepiri/architecture/microservices_design.md`
- `deepiri/architecture/service_communication.md`
- `deepiri/services/api-gateway/src/service_discovery.js`
- `deepiri/services/api-gateway/src/load_balancer.js`

---

### Systems Architect 2
**Location:** `deepiri/services/` (Event-Driven Architecture)
**Stack:** Kafka, RabbitMQ, Event Sourcing, CQRS, Message Queues
**Start Here:**
- Services: `deepiri/services/`
**Your Tasks:**
- Data & Event Architecture: Event-driven systems
- Data pipelines
- Real-time processing
- Message queues
- Event sourcing
**Files to Create:**
- `deepiri/architecture/event_driven_design.md`
- `deepiri/services/event-bus/` (create service)
- `deepiri/services/event-bus/src/kafka_producer.js`
- `deepiri/services/event-bus/src/event_processor.js`

---

### Systems Architect 3
**Location:** `deepiri/services/` & `deepiri/python_backend/app/middleware/`
**Stack:** Security Architecture, OAuth2, JWT, Encryption, API Security
**Start Here:**
- Middleware: `deepiri/python_backend/app/middleware/`
- Services: `deepiri/services/`
**Your Tasks:**
- Security & Compliance: Security architecture
- Data privacy
- Authentication systems
- API security
- Encryption at rest and in transit
**Files to Create:**
- `deepiri/architecture/security_design.md`
- `deepiri/services/auth-service/src/encryption.js`
- `deepiri/services/auth-service/src/api_security.js`
- `deepiri/python_backend/app/middleware/security.py`

---

### Systems Architect 4
**Location:** `deepiri/services/websocket-service/` & `deepiri/services/gamification-service/`
**Stack:** Real-time Systems, WebSockets, Scalability, Multiplayer Architecture
**Start Here:**
- WebSocket service: `deepiri/services/websocket-service/`
- Gamification service: `deepiri/services/gamification-service/`
**Your Tasks:**
- Scalability & Multiplayer Architecture:
  - Real-time challenge session scaling
  - Multiplayer game state management
  - Global deployment strategy
  - Load balancing for gamification
  - Disaster recovery for live sessions
**Files to Create:**
- `deepiri/architecture/multiplayer_scaling.md`
- `deepiri/services/websocket-service/src/session_scaling.js`
- `deepiri/services/websocket-service/src/game_state_manager.js`
- `deepiri/services/websocket-service/src/disaster_recovery.js`

---

### Systems Architect Intern
**Location:** `deepiri/architecture/` & `deepiri/services/`
**Stack:** System Design, Documentation, Architecture Patterns
**Start Here:**
- Architecture docs: `deepiri/MICROSERVICES_ARCHITECTURE.md`
- Services: `deepiri/services/`
**Your Tasks:**
- Supporting system architecture design
- Documentation
- Architecture pattern research
- Service design reviews
**Files to Create:**
- `deepiri/architecture/patterns.md`
- `deepiri/architecture/service_templates.md`
- `deepiri/architecture/design_reviews.md`

---

### Systems Engineer 1
**Location:** `deepiri/` (Cross-system integration)
**Stack:** System Integration, End-to-End Testing, API Integration, System Validation
**Start Here:**
- Root: `deepiri/`
- Integration tests: `deepiri/python_backend/tests/integration/`
**Your Tasks:**
- Ensure AI, backend, and cloud layers behave as one coherent system
- End-to-end system validation
- Cross-service integration
- System health monitoring
**Files to Create:**
- `deepiri/tests/integration/full_system_test.py`
- `deepiri/tests/integration/ai_backend_integration.py`
- `deepiri/scripts/system_health_check.sh`

---

### Systems Engineer 2
**Location:** `deepiri/tests/integration/` & `deepiri/services/`
**Stack:** Integration Testing, Error Handling, System Validation
**Start Here:**
- Integration tests: `deepiri/python_backend/tests/integration/`
- Services: `deepiri/services/`
**Your Tasks:**
- Integration Quality: End-to-end testing
- System validation
- Error handling coordination
- Service failure recovery
**Files to Create:**
- `deepiri/tests/integration/error_handling_test.py`
- `deepiri/tests/integration/service_recovery_test.py`
- `deepiri/scripts/validation_suite.sh`

---

### Platform Engineer 1 (Lead)
**Location:** `deepiri/platform/` & `deepiri/.github/`
**Stack:** Internal Developer Platform, CI/CD, Developer Tooling, Productivity Tools
**Start Here:**
- Platform directory: `deepiri/platform/` (create if needed)
- CI/CD: `deepiri/.github/workflows/`
**Your Tasks:**
- Internal developer platform
- Tooling and productivity
- Developer experience
- CI/CD pipelines
**Files to Create:**
- `deepiri/platform/developer_portal/`
- `deepiri/.github/workflows/ci.yml`
- `deepiri/platform/tooling/`

---

### Platform Engineer 2
**Location:** `deepiri/infrastructure/` & `deepiri/docker-compose.yml`
**Stack:** Terraform, Infrastructure as Code, Cloud Provisioning, Docker
**Start Here:**
- Docker compose: `deepiri/docker-compose.yml`
- Infrastructure: `deepiri/infrastructure/` (create)
**Your Tasks:**
- Infrastructure as Code (IaC)
- Resource provisioning
- Cloud infrastructure
- Container orchestration
**Files to Create:**
- `deepiri/infrastructure/terraform/`
- `deepiri/infrastructure/kubernetes/`
- `deepiri/infrastructure/docker/`

---

### Cloud/Infrastructure Engineer 1 (Lead)
**Location:** `deepiri/infrastructure/` & `deepiri/docker-compose.yml`
**Stack:** AWS/GCP/Azure, Kubernetes, Cloud Resource Management, Networking
**Start Here:**
- Docker compose: `deepiri/docker-compose.yml`
- Infrastructure: `deepiri/infrastructure/`
**Your Tasks:**
- Cloud resource management
- Networking
- Cost optimization
- Cloud architecture
**Files to Create:**
- `deepiri/infrastructure/cloud/aws/`
- `deepiri/infrastructure/cloud/gcp/`
- `deepiri/infrastructure/networking/`
- `deepiri/infrastructure/cost_optimization.md`

---

### Cloud/Infrastructure Engineer 2
**Location:** `deepiri/infrastructure/monitoring/` & `deepiri/infrastructure/security/`
**Stack:** Prometheus, Grafana, Cloud Security, Monitoring Tools
**Start Here:**
- Infrastructure: `deepiri/infrastructure/`
**Your Tasks:**
- Performance and security monitoring of cloud resources
- Alerting systems
- Security scanning
- Resource monitoring
**Files to Create:**
- `deepiri/infrastructure/monitoring/prometheus.yml`
- `deepiri/infrastructure/monitoring/grafana/`
- `deepiri/infrastructure/security/security_scanning.sh`
- `deepiri/infrastructure/monitoring/alerts.yml`

---

### Cloud/Infrastructure Engineer 3
**Location:** `deepiri/infrastructure/disaster_recovery/` & `deepiri/infrastructure/backup/`
**Stack:** Backup Systems, Disaster Recovery, High Availability, Failover
**Start Here:**
- Infrastructure: `deepiri/infrastructure/`
**Your Tasks:**
- Disaster recovery
- High-availability systems
- Backup strategies
- Failover mechanisms
**Files to Create:**
- `deepiri/infrastructure/disaster_recovery/plan.md`
- `deepiri/infrastructure/backup/backup_strategy.md`
- `deepiri/infrastructure/ha/high_availability.yml`
- `deepiri/infrastructure/failover/failover_config.yml`

---

### DevOps Engineer
**Location:** `deepiri/.github/workflows/` & `deepiri/infrastructure/`
**Stack:** CI/CD, Docker, Kubernetes, Monitoring, Observability
**Start Here:**
- CI/CD: `deepiri/.github/workflows/`
- Docker: `deepiri/docker-compose.yml`
**Your Tasks:**
- CI/CD pipelines
- Monitoring and observability
- Cloud infrastructure automation
- Deployment automation
**Files to Create:**
- `deepiri/.github/workflows/deploy.yml`
- `deepiri/infrastructure/ci_cd/`
- `deepiri/infrastructure/monitoring/observability.yml`

---

### Backend Intern 1
**Location:** `deepiri/services/*/tests/` & `deepiri/.github/workflows/`
**Stack:** Testing, CI/CD, Test Automation
**Start Here:**
- Services: `deepiri/services/`
- CI/CD: `deepiri/.github/workflows/`
**Your Tasks:**
- Test microservices
- CI/CD support
- Test automation
- Service testing
**Files to Create:**
- `deepiri/services/*/tests/` (in each service)
- `deepiri/.github/workflows/test.yml`

---

### Backend Intern 2
**Location:** `deepiri/services/*/docs/` & `deepiri/services/*/src/`
**Stack:** Documentation, API Documentation, Logging
**Start Here:**
- Services: `deepiri/services/`
**Your Tasks:**
- API documentation
- Logging improvements
- Support tasks with logs
- Service documentation
**Files to Create:**
- `deepiri/services/*/docs/API.md` (for each service)
- `deepiri/services/*/src/logging.js`
- `deepiri/docs/api_overview.md`

---

### Backend Intern 3
**Location:** `deepiri/services/*/tests/performance/` & `deepiri/services/*/src/`
**Stack:** Performance Testing, Load Testing, Bug Fixes
**Start Here:**
- Services: `deepiri/services/`
**Your Tasks:**
- Performance testing
- Bug fixes
- Load testing
- Service optimization
**Files to Create:**
- `deepiri/services/*/tests/performance/load_test.js`
- `deepiri/services/*/tests/performance/stress_test.js`
- `deepiri/scripts/performance_test_suite.sh`

---

## FRONTEND & UI TEAM

### Frontend Lead
**Location:** `deepiri/frontend/`
**Stack:** React, TypeScript, Vite, Tailwind CSS, UX/UI Design
**Start Here:**
- Frontend: `deepiri/frontend/`
- App: `deepiri/frontend/src/App.jsx`
**Your Tasks:**
- Oversee React/Vite web apps
- UX/UI consistency
- Component library
- Design system
**Files to Review:**
- `deepiri/frontend/src/App.jsx`
- `deepiri/frontend/src/components/`
- `deepiri/frontend/src/pages/`

---

### Graphic Designer
**Location:** `deepiri/frontend/src/assets/` & `deepiri/frontend/public/`
**Stack:** Design Tools (Figma, Adobe), SVG, Branding
**Start Here:**
- Assets: `deepiri/frontend/src/assets/`
- Public: `deepiri/frontend/public/`
**Your Tasks:**
- Logo Design
- Branding
- UI assets
- Design system assets
**Files to Create:**
- `deepiri/frontend/src/assets/logo.svg`
- `deepiri/frontend/src/assets/branding/`
- `deepiri/frontend/public/favicon.ico`
- `deepiri/frontend/src/styles/brand.css`

---

### Frontend Engineer 1
**Location:** `deepiri/frontend/src/pages/` & `deepiri/frontend/src/components/`
**Stack:** React, TypeScript, Firebase, Forms, Dashboards
**Start Here:**
- Pages: `deepiri/frontend/src/pages/`
- Components: `deepiri/frontend/src/components/`
**Your Tasks:**
- Web pages, forms, dashboards
- Firebase integration
- User interface components
- Form validation
**Files to Create:**
- `deepiri/frontend/src/pages/Dashboard.jsx`
- `deepiri/frontend/src/components/forms/`
- `deepiri/frontend/src/services/firebase.js`
- `deepiri/frontend/src/components/forms/FormValidation.jsx`

---

### Frontend Engineer 2
**Location:** `deepiri/frontend/src/components/charts/` & `deepiri/frontend/src/pages/analytics/`
**Stack:** React, TypeScript, Chart.js, D3.js, Data Visualization
**Start Here:**
- Analytics: `deepiri/frontend/src/pages/analytics/`
- Components: `deepiri/frontend/src/components/`
**Your Tasks:**
- AI/visualization dashboards
- Charting components
- Data visualization
- Analytics UI
**Files to Create:**
- `deepiri/frontend/src/components/charts/ProductivityChart.jsx`
- `deepiri/frontend/src/components/charts/AIInsightsChart.jsx`
- `deepiri/frontend/src/pages/analytics/Dashboard.jsx`
- `deepiri/frontend/src/components/charts/ChartLibrary.jsx`

---

### Frontend Engineer 3
**Location:** `deepiri/frontend/src/components/gamification/`
**Stack:** React, TypeScript, CSS Animations, Gamification UI
**Start Here:**
- Components: `deepiri/frontend/src/components/`
**Your Tasks:**
- Gamification visuals (badges, progress bars, avatars)
- Animation components
- Achievement UI
- Progress visualization
**Files to Create:**
- `deepiri/frontend/src/components/gamification/Badge.jsx`
- `deepiri/frontend/src/components/gamification/ProgressBar.jsx`
- `deepiri/frontend/src/components/gamification/Avatar.jsx`
- `deepiri/frontend/src/components/gamification/Animations.jsx`

---

### Frontend Engineer 4
**Location:** `deepiri/frontend/` (Performance & PWA)
**Stack:** React, TypeScript, PWA, Performance Optimization, Service Workers
**Start Here:**
- Frontend: `deepiri/frontend/`
- Config: `deepiri/frontend/vite.config.js`
**Your Tasks:**
- SPA optimization
- PWA support
- Performance optimization
- Service workers
- Code splitting
**Files to Create:**
- `deepiri/frontend/public/service-worker.js`
- `deepiri/frontend/src/utils/performance.js`
- `deepiri/frontend/vite.config.js` (optimize)
- `deepiri/frontend/public/manifest.json`

---

### Frontend Intern 1
**Location:** `deepiri/frontend/src/components/` & `deepiri/frontend/tests/`
**Stack:** React, Testing Library, Jest, Component Development
**Start Here:**
- Components: `deepiri/frontend/src/components/`
- Tests: `deepiri/frontend/tests/`
**Your Tasks:**
- UI testing
- Bug fixes
- Small component development
- Component testing
**Files to Create:**
- `deepiri/frontend/tests/components/`
- `deepiri/frontend/src/components/common/Button.jsx`
- `deepiri/frontend/src/components/common/Input.jsx`

---

## SECURITY, SUPPORT & QA TEAM

### IT Lead
**Location:** `deepiri/infrastructure/security/` & `deepiri/services/auth-service/`
**Stack:** Security Architecture, Network Defense, Cloud Security, Secure Microservices
**Start Here:**
- Infrastructure: `deepiri/infrastructure/`
- Auth service: `deepiri/services/auth-service/`
**Your Tasks:**
- Infrastructure support
- Organizational tech support
- Network defense
- Secure microservices
- Cloud security
**Files to Create:**
- `deepiri/infrastructure/security/network_defense.md`
- `deepiri/infrastructure/security/cloud_security.yml`
- `deepiri/services/auth-service/src/security.js`

---

### IT Internal Support
**Location:** `deepiri/docs/internal/` & `deepiri/scripts/onboarding/`
**Stack:** Internal Tools, Documentation, Onboarding Systems
**Start Here:**
- Docs: `deepiri/docs/`
**Your Tasks:**
- Employee tech support
- Employee onboarding/offboarding
- Software/hardware provisioning
- Organizational tech support
**Files to Create:**
- `deepiri/docs/internal/onboarding.md`
- `deepiri/docs/internal/tech_support.md`
- `deepiri/scripts/onboarding/setup.sh`

---

### IT External Support
**Location:** `deepiri/docs/user/` & `deepiri/frontend/src/pages/support/`
**Stack:** User Support, Documentation, Help Systems
**Start Here:**
- Docs: `deepiri/docs/`
- Frontend: `deepiri/frontend/src/pages/`
**Your Tasks:**
- User tech support
- User documentation
- Help center
- Support tickets
**Files to Create:**
- `deepiri/docs/user/getting_started.md`
- `deepiri/frontend/src/pages/support/HelpCenter.jsx`
- `deepiri/frontend/src/pages/support/Contact.jsx`

---

### Support Engineer
**Location:** `deepiri/docs/support/` & `deepiri/scripts/monitoring/`
**Stack:** Monitoring Tools, Documentation, Support Systems
**Start Here:**
- Docs: `deepiri/docs/`
**Your Tasks:**
- Resource monitoring (Github, Discord)
- Support documentation
- Monitoring dashboards
- Alert management
**Files to Create:**
- `deepiri/docs/support/monitoring.md`
- `deepiri/scripts/monitoring/resource_check.sh`
- `deepiri/docs/support/alerts.md`

---

### Security Operations
**Location:** `deepiri/infrastructure/security/` & `deepiri/scripts/security/`
**Stack:** Security Scanning, Dependency Management, Vulnerability Assessment
**Start Here:**
- Infrastructure: `deepiri/infrastructure/security/`
**Your Tasks:**
- Cybersecurity
- Cloud security
- Platform security
- Checking Dependabot alerts for dependency files
- Security scanning
**Files to Create:**
- `deepiri/scripts/security/dependency_scan.sh`
- `deepiri/scripts/security/vulnerability_check.sh`
- `deepiri/infrastructure/security/security_policy.md`
- `.github/dependabot.yml` (update)

---

### QA Lead
**Location:** `deepiri/tests/` & `deepiri/qa/`
**Stack:** Test Planning, Integration Testing, Test Strategy
**Start Here:**
- Tests: `deepiri/tests/`
- QA: `deepiri/qa/` (create)
**Your Tasks:**
- Test plans
- Integration testing
- Regression testing
- Test strategy
**Files to Create:**
- `deepiri/qa/test_plans.md`
- `deepiri/qa/integration_test_plan.md`
- `deepiri/qa/regression_test_plan.md`

---

### QA Engineer 1
**Location:** `deepiri/tests/manual/` & `deepiri/qa/manual/`
**Stack:** Manual Testing, User Acceptance Testing, Test Cases
**Start Here:**
- Tests: `deepiri/tests/`
**Your Tasks:**
- Manual testing
- User acceptance testing (UAT)
- Bug verification
- Test case creation
**Files to Create:**
- `deepiri/qa/manual/test_cases.md`
- `deepiri/qa/manual/uat_scenarios.md`
- `deepiri/qa/manual/bug_reports.md`

---

### QA Engineer 2
**Location:** `deepiri/tests/automation/` & `deepiri/qa/automation/`
**Stack:** Automation Testing, API Testing, Selenium, Playwright, Test Reporting
**Start Here:**
- Tests: `deepiri/tests/`
**Your Tasks:**
- Automation testing
- API testing
- Reporting
- Test automation framework
**Files to Create:**
- `deepiri/tests/automation/api_tests.js`
- `deepiri/tests/automation/e2e_tests.js`
- `deepiri/qa/automation/test_reports/`
- `deepiri/tests/automation/framework/`

---

### QA Intern 1
**Location:** `deepiri/tests/` & `deepiri/qa/`
**Stack:** Test Scripts, Bug Tracking, Basic QA Tasks
**Start Here:**
- Tests: `deepiri/tests/`
**Your Tasks:**
- Test scripts
- Bug tracking
- Basic QA tasks
- Test data preparation
**Files to Create:**
- `deepiri/tests/scripts/`
- `deepiri/qa/bug_tracking.md`
- `deepiri/tests/data/test_data.json`

---

### QA Intern 2
**Location:** `deepiri/tests/regression/` & `deepiri/qa/`
**Stack:** Regression Testing, Test Suite Maintenance, Environment Setup
**Start Here:**
- Tests: `deepiri/tests/`
**Your Tasks:**
- Regression test suite maintenance
- Environment setup help
- Test environment configuration
- Test data management
**Files to Create:**
- `deepiri/tests/regression/regression_suite.js`
- `deepiri/qa/environments/test_env_setup.md`
- `deepiri/tests/config/test_config.json`

---

## DESKTOP IDE TEAM

### Desktop IDE Developers
**Location:** `desktop-ide-deepiri/`
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
5. **Work on "Your Tasks"** and "Files to Create/Work On"
6. **Ask questions** in team channels if stuck

---

## IMPORTANT LINKS

- **Main README:** `deepiri/README.md`
- **Microservices Architecture:** `deepiri/MICROSERVICES_ARCHITECTURE.md`
- **AI Team README:** `deepiri/README_AI_TEAM.md`
- **Backend Team README:** `deepiri/README_BACKEND_TEAM.md`
- **Frontend Team README:** `deepiri/README_FRONTEND_TEAM.md`
- **Desktop IDE README:** `desktop-ide-deepiri/README.md`

---

**Last Updated:** 2024
**Questions?** Contact your team lead or check team-specific READMEs.
