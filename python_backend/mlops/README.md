# MLOps Infrastructure - Deepiri

## Overview

Comprehensive MLOps infrastructure for automated model lifecycle management, monitoring, and deployment.

## Components

### 1. CI/CD Pipeline (`ci/model_ci_pipeline.py`)

Automated CI/CD pipeline for ML models:

- **Unit Testing**: Tests on dataset slices
- **Model Validation**: Validates against metrics thresholds
- **MLflow Registration**: Registers models in MLflow
- **Staging Deployment**: Deploys to staging environment
- **Staging Tests**: Validates staging deployment
- **Production Deployment**: Canary or full deployment

**Usage:**
```python
from mlops.ci.model_ci_pipeline import ModelCIPipeline

pipeline = ModelCIPipeline()
result = pipeline.run_full_pipeline(
    model_path="models/task_classifier.pkl",
    model_name="task_classifier",
    test_data_path="data/test.csv",
    validation_metrics={
        'accuracy': 0.85,
        'precision': 0.82,
        'recall': 0.80,
        'f1_score': 0.81
    }
)
```

### 2. Model Monitoring (`monitoring/model_monitor.py`)

Real-time model monitoring:

- **Performance Tracking**: Accuracy, latency, error rate
- **Data Drift Detection**: Detects changes in input distribution
- **Prediction Drift**: Monitors prediction distribution changes
- **Alerting**: Alerts on performance degradation

**Usage:**
```python
from mlops.monitoring.model_monitor import get_model_monitor

monitor = get_model_monitor()

# Record prediction
monitor.record_prediction(
    model_name="task_classifier",
    prediction=prediction,
    actual=actual,
    latency_ms=50
)

# Check performance
performance = monitor.check_model_performance("task_classifier")

# Detect drift
drift = monitor.detect_data_drift("task_classifier", current_features)
```

### 3. Model Registry (`registry/model_registry.py`)

Model versioning and lifecycle management:

- **Model Registration**: Register models with metadata
- **Version Management**: Semantic versioning
- **Stage Management**: Staging, production, archived
- **A/B Testing**: Configure A/B tests between versions

**Usage:**
```python
from mlops.registry.model_registry import get_model_registry

registry = get_model_registry()

# Register model
version = registry.register_model(
    model_name="task_classifier",
    model_path="models/v1.pkl",
    metadata={
        'accuracy': 0.85,
        'training_data': 'data/train.csv',
        'algorithm': 'transformer'
    }
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

### 4. Deployment Automation (`deployment/deployment_automation.py`)

Automated deployment strategies:

- **Canary Deployment**: Gradual rollout (10% → 100%)
- **Blue-Green Deployment**: Zero-downtime deployment
- **A/B Testing**: Split traffic between versions
- **Rollback**: Automatic rollback on failure

**Usage:**
```python
from mlops.deployment.deployment_automation import get_deployment_automation

deployment = get_deployment_automation()

# Canary deployment
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

# Rollback if needed
deployment.rollback("task_classifier")
```

## Environment Setup

### Prerequisites

1. **MLflow**: Model tracking and registry
   ```bash
   pip install mlflow
   mlflow server --host 0.0.0.0 --port 5000
   ```

2. **Kubernetes**: For deployment (optional)
   ```bash
   kubectl version
   ```

3. **Monitoring Stack**: Prometheus + Grafana
   ```bash
   # Install Prometheus
   # Install Grafana
   ```

### Configuration

Set environment variables:

```bash
export MLFLOW_TRACKING_URI="http://localhost:5000"
export STAGING_MODEL_PATH="models/staging"
export PRODUCTION_MODEL_PATH="models/production"
export MODEL_REGISTRY_PATH="model_registry"
export PINECONE_API_KEY="your-key"  # Optional
export WEAVIATE_URL="http://localhost:8080"  # Optional
```

## Workflow

### 1. Model Training

```python
# Train model
model = train_model(training_data)

# Evaluate
metrics = evaluate_model(model, test_data)
```

### 2. CI/CD Pipeline

```python
# Run CI/CD pipeline
pipeline = ModelCIPipeline()
result = pipeline.run_full_pipeline(
    model_path="models/model.pkl",
    model_name="my_model",
    test_data_path="data/test.csv",
    validation_metrics=metrics
)
```

### 3. Model Registration

```python
# Register in registry
registry = get_model_registry()
version = registry.register_model(
    model_name="my_model",
    model_path="models/model.pkl",
    metadata=metrics
)
```

### 4. Deployment

```python
# Deploy to staging
deployment = get_deployment_automation()
deployment.deploy_model(
    model_name="my_model",
    model_version=version,
    strategy="canary"
)
```

### 5. Monitoring

```python
# Monitor in production
monitor = get_model_monitor()
monitor.set_baseline("my_model", metrics)

# Continuous monitoring
monitor.record_prediction("my_model", prediction, actual)
performance = monitor.check_model_performance("my_model")
```

## A/B Testing

### Setup A/B Test

```python
registry = get_model_registry()

# Register both versions
version_a = registry.register_model("model", "path_a", metadata_a)
version_b = registry.register_model("model", "path_b", metadata_b)

# Setup A/B test
registry.setup_ab_test(
    model_name="model",
    version_a=version_a,
    version_b=version_b,
    traffic_split=0.5  # 50% to each
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
```

## Monitoring Dashboards

### Metrics to Monitor

1. **Performance Metrics**:
   - Accuracy
   - Precision
   - Recall
   - F1 Score
   - Latency (p50, p95, p99)
   - Throughput

2. **Data Quality**:
   - Data drift score
   - Feature distribution changes
   - Missing values
   - Outliers

3. **System Health**:
   - Pod status
   - CPU/Memory usage
   - Request rate
   - Error rate

### Grafana Dashboards

Create dashboards for:
- Model performance over time
- Data drift detection
- Deployment status
- A/B test comparison
- System resource usage

## Best Practices

1. **Always test in staging** before production
2. **Use canary deployments** for high-risk changes
3. **Set up alerts** for performance degradation
4. **Monitor data drift** regularly
5. **Version all models** with semantic versioning
6. **Document model metadata** thoroughly
7. **Automate rollback** on failures
8. **Track A/B test results** systematically

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

## Next Steps

1. Set up Prometheus + Grafana for visualization
2. Configure alerting (PagerDuty, Slack)
3. Implement automated retraining pipelines
4. Set up model explainability tracking
5. Implement data quality checks
6. Create deployment playbooks
