# MLOps Team Onboarding Guide

## Overview

This guide will help MLOps engineers get started with the Deepiri MLOps infrastructure. You'll learn how to set up your environment, use the CI/CD pipelines, monitor models, and deploy to production.

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
docker compose -f docker-compose.ml-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.ml-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f mlflow
docker compose -f docker-compose.dev.yml logs -f jupyter
# ... etc for all services
```

---

## Quick Start

### 0. Initial Repository Setup

**First, clone the repository and set up Git hooks:**

```bash
# Clone the repository
git clone <repository-url>
cd deepiri-platform

# Set up Git hooks (REQUIRED - protects main and dev branches)
./setup-hooks.sh
```

**⚠️ IMPORTANT:** Git hooks protect the `main` and `dev` branches from accidental pushes. See [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) for details.

### 1. Environment Setup

```bash
# Navigate to MLOps directory
cd deepiri/diri-cyrex/mlops

# Run setup script (Linux/Mac)
bash scripts/setup_mlops_environment.sh

# Or manually (Windows)
python -m venv venv
venv\Scripts\activate  # Windows
source venv/bin/activate  # Linux/Mac

pip install -r requirements.txt
pip install mlflow kubernetes prometheus-client
```

### 2. Build and Start Required Microservices (MLOps Team)

**MLOps team only needs these services:**
- MLflow (for model tracking and registry)
- Python Agent (for model deployment testing) - **cyrex**
- MongoDB (for model registry data)
- InfluxDB (for monitoring metrics)
- Jupyter (for experimentation, optional)

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
# Start only the services needed for MLOps
docker-compose -f docker-compose.dev.yml up -d \
  mongodb \
  influxdb \
  mlflow \
  cyrex \
  jupyter

# Check service status
docker-compose -f docker-compose.dev.yml ps

# View logs
docker-compose -f docker-compose.dev.yml logs -f mlflow
docker-compose -f docker-compose.dev.yml logs -f cyrex
```

**Note:** If you encounter build freezing at step 113/120, the auto-build script will use CPU fallback automatically. See `diri-cyrex/README_BUILD.md` for troubleshooting.

**MLOps Team Services:**
- **MLflow:** mlflow (port 5500) - Model tracking and registry
- **Python Agent:** cyrex (port 8000) - For model deployment testing
- **Jupyter:** jupyter (port 8888) - For experimentation (optional)
- **Databases:** mongodb, influxdb

**Services NOT needed for MLOps:**
- `api-gateway` (unless testing full integration)
- `deepiri-web-frontend-dev` (deepiri-web-frontend team)
- `user-service`, `task-service`, etc. (backend team)
- `redis` (unless needed for caching)
- `mongo-express` (optional)

**Access Points:**
- MLflow UI: http://localhost:5500
- Python Agent: http://localhost:8000
- Jupyter: http://localhost:8888

### 3. Start Services (Alternative - Manual)

```bash
# Start MLflow manually (if not using Docker)
mlflow server --host 0.0.0.0 --port 5000

# Start monitoring stack (if using separate docker-compose)
docker-compose -f docker/docker-compose.mlops.yml up -d

# Access MLflow UI: http://localhost:5000
# Access Grafana: http://localhost:3000 (admin/admin)
```

### 4. Stop Services (When Done)

```bash
# Stop all MLOps-related services
docker-compose -f docker-compose.dev.yml stop \
  mlflow \
  cyrex \
  jupyter

# Or stop everything
docker-compose -f docker-compose.dev.yml down
```

## Core Responsibilities

### MLOps Engineer 1: CI/CD for Models

**Focus**: Automating model updates and monitoring engagement metrics

**Key Tasks**:
1. **Model CI/CD Pipeline**
   - Location: `diri-cyrex/mlops/ci/model_ci_pipeline.py`
   - Automates: Testing → Validation → Registration → Staging → Production
   - Usage:
     ```python
     from mlops.ci.model_ci_pipeline import ModelCIPipeline
     
     pipeline = ModelCIPipeline()
     result = pipeline.run_full_pipeline(
         model_path="models/task_classifier.pkl",
         model_name="task_classifier",
         test_data_path="data/test.csv",
         validation_metrics={'accuracy': 0.85}
     )
     ```

2. **Automated Testing**
   - Unit tests on dataset slices
   - Model validation against thresholds
   - Staging environment tests

3. **Deployment Automation**
   - Canary deployments
   - Blue-green deployments
   - A/B testing setup

**Files to Work On**:
- `mlops/ci/model_ci_pipeline.py` - Main CI/CD pipeline
- `mlops/deployment/deployment_automation.py` - Deployment strategies
- `mlops/scripts/run_ci_pipeline.sh` - CI/CD automation scripts

### MLOps Engineer 2: Performance Monitoring & Deployment

**Focus**: Performance monitoring, deployment automation, resource optimization

**Key Tasks**:
1. **Model Monitoring**
   - Location: `diri-cyrex/mlops/monitoring/model_monitor.py`
   - Monitors: Performance, drift, data quality
   - Usage:
     ```python
     from mlops.monitoring.model_monitor import get_model_monitor
     
     monitor = get_model_monitor()
     monitor.record_prediction("model_name", prediction, actual)
     performance = monitor.check_model_performance("model_name")
     drift = monitor.detect_data_drift("model_name", features)
     ```

2. **Performance Dashboards**
   - Grafana dashboards for model metrics
   - Prometheus metrics collection
   - Real-time alerting

3. **Resource Optimization**
   - GPU utilization monitoring
   - Model quantization for efficiency
   - Caching strategies

**Files to Work On**:
- `mlops/monitoring/model_monitor.py` - Monitoring service
- `mlops/monitoring/dashboards/` - Grafana dashboard configs
- `mlops/monitoring/alerts/` - Alert configurations

## Model Registry & Versioning

### Model Registry Service

**Location**: `diri-cyrex/mlops/registry/model_registry.py`

**Usage**:
```python
from mlops.registry.model_registry import get_model_registry

registry = get_model_registry()

# Register model
version = registry.register_model(
    model_name="task_classifier",
    model_path="models/v1.pkl",
    metadata={'accuracy': 0.85, 'algorithm': 'transformer'}
)

# Promote to production
registry.promote_to_stage("task_classifier", version, "production")

# Setup A/B test
registry.setup_ab_test(
    model_name="task_classifier",
    version_a="1.0.0",
    version_b="1.1.0",
    traffic_split=0.5
)
```

### Versioning Strategy

- **Semantic Versioning**: `MAJOR.MINOR.PATCH`
- **Stages**: `staging` → `production` → `archived`
- **Metadata**: Accuracy, training data, algorithm, hyperparameters

## Monitoring & Observability

### Metrics to Monitor

1. **Performance Metrics**:
   - Accuracy, Precision, Recall, F1 Score
   - Latency (p50, p95, p99)
   - Throughput (requests/second)

2. **Data Quality**:
   - Data drift score
   - Feature distribution changes
   - Missing values, outliers

3. **System Health**:
   - Pod status (Kubernetes)
   - CPU/Memory usage
   - Error rate

### Setting Up Monitoring

```python
from mlops.monitoring.model_monitor import get_model_monitor

monitor = get_model_monitor()

# Set baseline
monitor.set_baseline("model_name", {
    'accuracy': 0.85,
    'avg_latency_ms': 50,
    'error_rate': 0.01
})

# Record predictions
monitor.record_prediction(
    model_name="model_name",
    prediction=prediction,
    actual=actual,
    latency_ms=45
)

# Check performance
performance = monitor.check_model_performance("model_name")
if performance['status'] == 'degraded':
    # Alert and potentially rollback
    pass
```

### Grafana Dashboards

Create dashboards for:
- Model performance over time
- Data drift detection
- Deployment status
- A/B test comparison
- System resource usage

**Location**: `mlops/monitoring/dashboards/`

## Deployment Strategies

### 1. Canary Deployment

Gradual rollout (10% → 50% → 100%)

```python
from mlops.deployment.deployment_automation import get_deployment_automation

deployment = get_deployment_automation()
result = deployment.deploy_model(
    model_name="task_classifier",
    model_version="1.1.0",
    strategy="canary",
    config={
        'initial_traffic': 10,
        'increment': 10,
        'interval_minutes': 5
    }
)
```

### 2. Blue-Green Deployment

Zero-downtime deployment

```python
result = deployment.deploy_model(
    model_name="task_classifier",
    model_version="1.1.0",
    strategy="blue_green"
)
```

### 3. A/B Testing

Split traffic between versions

```python
# Setup A/B test
registry.setup_ab_test(
    model_name="task_classifier",
    version_a="1.0.0",
    version_b="1.1.0",
    traffic_split=0.5
)

# Deploy
deployment.deploy_model(
    model_name="task_classifier",
    model_version="1.1.0",
    strategy="ab_test"
)
```

## CI/CD Workflow

### Complete Workflow

1. **Train Model**
   ```python
   model = train_model(training_data)
   metrics = evaluate_model(model, test_data)
   ```

2. **Run CI/CD Pipeline**
   ```python
   pipeline = ModelCIPipeline()
   result = pipeline.run_full_pipeline(
       model_path="models/model.pkl",
       model_name="my_model",
       test_data_path="data/test.csv",
       validation_metrics=metrics
   )
   ```

3. **Register Model**
   ```python
   registry = get_model_registry()
   version = registry.register_model(
       model_name="my_model",
       model_path="models/model.pkl",
       metadata=metrics
   )
   ```

4. **Deploy to Staging**
   ```python
   deployment = get_deployment_automation()
   deployment.deploy_model("my_model", version, strategy="canary")
   ```

5. **Monitor & Promote**
   ```python
   monitor = get_model_monitor()
   performance = monitor.check_model_performance("my_model")
   
   if performance['status'] == 'healthy':
       registry.promote_to_stage("my_model", version, "production")
   ```

## A/B Testing Workflow

### Setup A/B Test

```python
# Register both versions
version_a = registry.register_model("model", "path_a", metadata_a)
version_b = registry.register_model("model", "path_b", metadata_b)

# Setup A/B test
registry.setup_ab_test(
    model_name="model",
    version_a=version_a,
    version_b=version_b,
    traffic_split=0.5
)

# Deploy
deployment.deploy_model("model", version_b, strategy="ab_test")
```

### Monitor A/B Test

```python
# Compare performance
performance_a = monitor.check_model_performance("model", version_a)
performance_b = monitor.check_model_performance("model", version_b)

# Decide winner
if performance_b['accuracy'] > performance_a['accuracy']:
    registry.promote_to_stage("model", version_b, "production")
    # End A/B test
```

## Rollback Procedures

### Automatic Rollback

```python
# On deployment failure
deployment.rollback("model_name")

# To specific version
deployment.rollback("model_name", target_version="1.0.0")
```

### Manual Rollback

1. Check current version: `registry.get_production_model("model_name")`
2. Switch to previous version: `deployment.rollback("model_name")`
3. Verify: `monitor.check_model_performance("model_name")`

## Troubleshooting

### Model Performance Degradation

1. Check data drift: `monitor.detect_data_drift()`
2. Check prediction drift: `monitor.detect_prediction_drift()`
3. Review recent changes
4. Consider rollback: `deployment.rollback()`

### Deployment Failures

1. Check health: `deployment._check_deployment_health()`
2. Review logs
3. Check resource constraints
4. Rollback if needed

### Monitoring Issues

1. Verify MLflow connection
2. Check alert thresholds
3. Review monitoring data collection
4. Validate baseline metrics

## Best Practices

1. **Always test in staging** before production
2. **Use canary deployments** for high-risk changes
3. **Set up alerts** for performance degradation
4. **Monitor data drift** regularly
5. **Version all models** with semantic versioning
6. **Document model metadata** thoroughly
7. **Automate rollback** on failures
8. **Track A/B test results** systematically

## Tools & Technologies

- **MLflow**: Model tracking and registry
- **Kubernetes**: Container orchestration
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Docker**: Containerization
- **Git**: Version control

## Next Steps

1. ✅ Set up local environment
2. ✅ Start MLflow server
3. ✅ Run test CI/CD pipeline
4. ✅ Create monitoring dashboard
5. ✅ Deploy test model
6. ✅ Set up A/B test
7. ✅ Configure alerts

## Resources

- **MLOps README**: `diri-cyrex/mlops/README.md`
- **CI/CD Pipeline**: `diri-cyrex/mlops/ci/model_ci_pipeline.py`
- **Model Registry**: `diri-cyrex/mlops/registry/model_registry.py`
- **Monitoring**: `diri-cyrex/mlops/monitoring/model_monitor.py`
- **Deployment**: `diri-cyrex/mlops/deployment/deployment_automation.py`

## Getting Help

- Check logs: `logs/mlops.log`
- Review documentation: `docs/MLOPS_TEAM_ONBOARDING.md`
- Ask team: MLOps channel in Slack
- Review code: `diri-cyrex/mlops/`

---

**Welcome to the MLOps team! 🚀**


