# MLflow Model Registry Full Implementation Guide

## Table of Contents

1. [Introduction: What is MLflow and Why Do We Need It?](#introduction)
2. [Understanding the Model Registry Concept](#understanding-the-model-registry)
3. [Setting Up Your Development Environment](#setting-up-environment)
4. [Step 1: Basic MLflow Tracking](#step-1-basic-tracking)
5. [Step 2: Logging Your First Model](#step-2-logging-models)
6. [Step 3: Understanding Model Versions](#step-3-model-versions)
7. [Step 4: Building the Model Registry Service](#step-4-building-registry)
8. [Step 5: Model Lifecycle Management](#step-5-lifecycle-management)
9. [Step 6: Integration with Training Pipelines](#step-6-training-integration)
10. [Step 7: Model Serving and Deployment](#step-7-deployment)
11. [Step 8: Advanced Features](#step-8-advanced-features)
12. [Step 9: Production Best Practices](#step-9-production-practices)
13. [Troubleshooting and Common Issues](#troubleshooting)

---

## Introduction: What is MLflow and Why Do We Need It?

### The Problem Without MLflow

Imagine you're training machine learning models. You might:
- Save models with names like `model_v1.pkl`, `model_v2_final.pkl`, `model_v3_really_final.pkl`
- Forget which hyperparameters you used for each model
- Lose track of which model performed best
- Struggle to reproduce results from last month
- Have no idea which model is running in production

This chaos makes it impossible to manage models at scale.

### What MLflow Solves

MLflow is an open-source platform that provides:
1. **Experiment Tracking**: Log parameters, metrics, and artifacts for every run
2. **Model Registry**: Centralized store for model versions with lifecycle management
3. **Model Serving**: Deploy models as REST APIs
4. **Reproducibility**: Track code, data, and environment for every experiment

Think of MLflow as "Git for machine learning models" - it tracks versions, allows you to compare experiments, and manages what goes into production.

### The Model Registry Specifically

The Model Registry is like a library for your models:
- **Register**: Save models with metadata
- **Version**: Track multiple versions of the same model
- **Stage**: Mark models as "Staging", "Production", or "Archived"
- **Deploy**: Automatically serve the right model version
- **Monitor**: Track which models are in use

---

## Understanding the Model Registry Concept

### Key Concepts

**Model Name**: A logical name like "sentiment-classifier" or "price-predictor". Multiple versions can share the same name.

**Model Version**: Each time you register a model with the same name, it gets a new version number (1, 2, 3, etc.).

**Model Stage**: A label indicating the model's status:
- **None**: Just registered, not staged
- **Staging**: Being tested before production
- **Production**: Currently serving real users
- **Archived**: Old model, kept for reference

**Model Artifacts**: The actual model files (weights, configuration, preprocessing code).

**Model Metadata**: Information about the model (metrics, hyperparameters, training data version).

### The Workflow

```
Train Model → Log to MLflow → Register Model → Promote to Staging → 
Test in Staging → Promote to Production → Monitor → Archive Old Versions
```

---

## Setting Up Your Development Environment

### Prerequisites

You need:
- Python 3.8 or higher
- Access to the Deepiri platform (Docker containers running)
- Basic understanding of Python

### Verify MLflow is Running

First, check that MLflow is accessible:

```bash
# Check if MLflow container is running
docker ps | grep mlflow

# Access MLflow UI (should be at http://localhost:5500)
curl http://localhost:5500
```

If MLflow isn't running, start it:

```bash
cd deepiri-platform
docker-compose -f docker-compose.dev.yml up -d mlflow
```

### Install MLflow Python Package

Create a virtual environment and install MLflow:

```bash
# Create virtual environment
python -m venv mlflow-env
source mlflow-env/bin/activate  # On Windows: mlflow-env\Scripts\activate

# Install MLflow
pip install mlflow

# For model serving, you may also need:
pip install mlflow[extras]
```

### Set Environment Variables

Create a `.env` file or export these variables:

```bash
export MLFLOW_TRACKING_URI="http://localhost:5500"
export MLFLOW_TRACKING_USERNAME=""  # If authentication is enabled
export MLFLOW_TRACKING_PASSWORD=""  # If authentication is enabled
```

### Test the Connection

Create a test file `test_mlflow_connection.py`:

```python
import mlflow
import os

# Set tracking URI
mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5500"))

# Test connection
try:
    experiments = mlflow.search_experiments()
    print(f"Successfully connected to MLflow!")
    print(f"Found {len(experiments)} experiments")
except Exception as e:
    print(f"Connection failed: {e}")
```

Run it:

```bash
python test_mlflow_connection.py
```

If you see "Successfully connected", you're ready to proceed.

---

## Step 1: Basic MLflow Tracking

### What is Tracking?

Tracking means recording information about your experiments. Every time you train a model, you create a "run" that stores:
- Parameters (hyperparameters, configuration)
- Metrics (accuracy, loss, etc.)
- Artifacts (model files, plots, data samples)
- Code version (Git commit)
- Environment (Python version, package versions)

### Your First Tracked Experiment

Let's create a simple example. We'll train a basic model and track it.

Create `step1_basic_tracking.py`:

```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import pandas as pd
import os

# Set tracking URI
mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5500"))

# Create or get experiment
experiment_name = "my-first-experiment"
mlflow.set_experiment(experiment_name)

# Start a run
with mlflow.start_run(run_name="random-forest-baseline"):
    
    # Log parameters
    n_estimators = 100
    max_depth = 10
    mlflow.log_param("n_estimators", n_estimators)
    mlflow.log_param("max_depth", max_depth)
    mlflow.log_param("model_type", "RandomForest")
    
    # Prepare dummy data (replace with your actual data loading)
    # For this example, we'll create synthetic data
    from sklearn.datasets import make_classification
    X, y = make_classification(n_samples=1000, n_features=20, n_informative=10, 
                              n_redundant=10, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train model
    model = RandomForestClassifier(n_estimators=n_estimators, max_depth=max_depth, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("train_samples", len(X_train))
    mlflow.log_metric("test_samples", len(X_test))
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
    
    print(f"Run completed! Accuracy: {accuracy:.4f}")
    print(f"View in MLflow UI: {mlflow.get_tracking_uri()}")
```

Run it:

```bash
python step1_basic_tracking.py
```

### Understanding What Happened

1. **Experiment Created**: MLflow created an experiment called "my-first-experiment"
2. **Run Started**: A new run was created with the name "random-forest-baseline"
3. **Data Logged**: Parameters and metrics were stored
4. **Model Saved**: The trained model was saved as an artifact

### View Your Results

Open your browser and go to `http://localhost:5500`. You should see:
- Your experiment in the list
- Your run with all logged parameters and metrics
- The model artifact you can download

### Exercise: Log Multiple Runs

Modify the script to try different hyperparameters:

```python
# Try different configurations
configs = [
    {"n_estimators": 50, "max_depth": 5},
    {"n_estimators": 100, "max_depth": 10},
    {"n_estimators": 200, "max_depth": 15},
]

for config in configs:
    with mlflow.start_run(run_name=f"rf-{config['n_estimators']}-trees"):
        mlflow.log_params(config)
        # ... train and evaluate with these params
```

This lets you compare different configurations side-by-side in the MLflow UI.

---

## Step 2: Logging Your First Model

### What Does "Logging a Model" Mean?

When you log a model, MLflow:
1. Saves the model files (weights, configuration)
2. Records how to load the model (framework, version)
3. Stores any preprocessing code needed
4. Creates a unique identifier (run ID) for this model

### Different Model Types

MLflow supports many frameworks. Here are common ones:

**Scikit-learn:**
```python
import mlflow.sklearn
mlflow.sklearn.log_model(model, "model")
```

**PyTorch:**
```python
import mlflow.pytorch
mlflow.pytorch.log_model(model, "model")
```

**TensorFlow/Keras:**
```python
import mlflow.tensorflow
mlflow.tensorflow.log_model(model, "model")
```

**Custom Python Function:**
```python
import mlflow.pyfunc

class MyModel(mlflow.pyfunc.PythonModel):
    def load_context(self, context):
        # Load any artifacts needed
        pass
    
    def predict(self, context, model_input):
        # Your prediction logic
        return predictions

mlflow.pyfunc.log_model("model", python_model=MyModel())
```

### Complete Example: Logging a Scikit-learn Model

Create `step2_log_model.py`:

```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score
from sklearn.datasets import make_classification
import os

mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5500"))
mlflow.set_experiment("model-logging-example")

with mlflow.start_run(run_name="complete-model-example"):
    # Prepare data
    X, y = make_classification(n_samples=1000, n_features=20, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, average='weighted')
    recall = recall_score(y_test, y_pred, average='weighted')
    
    # Log everything
    mlflow.log_params({
        "n_estimators": 100,
        "max_depth": None,
        "random_state": 42
    })
    
    mlflow.log_metrics({
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall
    })
    
    # Log model - THIS IS THE KEY STEP
    mlflow.sklearn.log_model(
        model,
        "model",
        registered_model_name="my-first-registered-model"  # This registers it!
    )
    
    print(f"Model logged! Run ID: {mlflow.active_run().info.run_id}")
```

### Understanding Model Artifacts

When you log a model, MLflow creates a directory structure:

```
artifacts/
  model/
    MLmodel          # Metadata about the model
    model.pkl        # The actual model file
    conda.yaml       # Environment specification
    requirements.txt # Python dependencies
```

The `MLmodel` file tells MLflow:
- What framework was used
- How to load the model
- What Python version is needed
- What packages are required

### Loading a Logged Model

You can load a logged model later:

```python
import mlflow.sklearn

# Load model from a specific run
run_id = "your-run-id-here"
model = mlflow.sklearn.load_model(f"runs:/{run_id}/model")

# Use it for predictions
predictions = model.predict(new_data)
```

---

## Step 3: Understanding Model Versions

### What is Model Versioning?

Just like code versioning (Git), model versioning tracks changes over time. Each time you register a model with the same name, it gets a new version number.

### Registering Your First Model

"Registering" a model means giving it a name in the Model Registry. This is different from just logging it.

Create `step3_register_model.py`:

```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import os

mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5500"))
mlflow.set_experiment("model-registry-example")

# Train and log model
with mlflow.start_run(run_name="register-version-1"):
    X, y = make_classification(n_samples=1000, n_features=20, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    accuracy = accuracy_score(y_test, model.predict(X_test))
    mlflow.log_metric("accuracy", accuracy)
    
    # Register the model with a name
    model_name = "sentiment-classifier"
    mlflow.sklearn.log_model(
        model,
        "model",
        registered_model_name=model_name  # This creates version 1
    )
    
    print(f"Model registered as '{model_name}' version 1")

# Train a new version
with mlflow.start_run(run_name="register-version-2"):
    # Same data, different hyperparameters
    model_v2 = RandomForestClassifier(n_estimators=200, random_state=42)
    model_v2.fit(X_train, y_train)
    
    accuracy_v2 = accuracy_score(y_test, model_v2.predict(X_test))
    mlflow.log_metric("accuracy", accuracy_v2)
    
    # Register with the same name - creates version 2
    mlflow.sklearn.log_model(
        model_v2,
        "model",
        registered_model_name=model_name  # Same name = new version
    )
    
    print(f"Model registered as '{model_name}' version 2")
```

### Viewing Registered Models

In the MLflow UI:
1. Go to `http://localhost:5500`
2. Click "Models" in the top menu
3. You'll see your registered model "sentiment-classifier"
4. Click on it to see versions 1 and 2

### Loading a Specific Version

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()
model_name = "sentiment-classifier"

# Load version 1
model_v1 = mlflow.sklearn.load_model(f"models:/{model_name}/1")

# Load version 2
model_v2 = mlflow.sklearn.load_model(f"models:/{model_name}/2")

# Load latest version
model_latest = mlflow.sklearn.load_model(f"models:/{model_name}/latest")
```

### Model Stages

Stages are labels that indicate a model's status. Let's promote version 2 to "Staging":

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()
model_name = "sentiment-classifier"

# Transition version 2 to Staging
client.transition_model_version_stage(
    name=model_name,
    version=2,
    stage="Staging"
)

# Now you can load the staging model
staging_model = mlflow.sklearn.load_model(f"models:/{model_name}/Staging")
```

### Understanding the Model Registry Structure

```
Model Registry
├── sentiment-classifier (Model Name)
│   ├── Version 1
│   │   ├── Stage: None
│   │   ├── Accuracy: 0.85
│   │   └── Run ID: abc123
│   ├── Version 2
│   │   ├── Stage: Staging
│   │   ├── Accuracy: 0.87
│   │   └── Run ID: def456
│   └── Version 3
│       ├── Stage: Production
│       ├── Accuracy: 0.89
│       └── Run ID: ghi789
```

---

## Step 4: Building the Model Registry Service

### Why Build a Service?

While MLflow provides the registry, you need a service layer that:
- Integrates with your application code
- Provides a clean API for model operations
- Handles errors gracefully
- Adds business logic (validation, approval workflows)
- Connects to your deployment system

### Architecture Overview

```
Your Application
    ↓
Model Registry Service (this is what we're building)
    ↓
MLflow Client
    ↓
MLflow Server
    ↓
PostgreSQL (metadata) + MinIO (artifacts)
```

### Step 4.1: Create the Service Structure

Create a new directory structure:

```
deepiri-platform/platform-services/backend/deepiri-model-registry-service/
├── src/
│   ├── __init__.py
│   ├── registry/
│   │   ├── __init__.py
│   │   ├── mlflow_registry.py      # MLflow integration
│   │   ├── model_service.py        # Business logic
│   │   └── model_validator.py      # Validation logic
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes.py                # REST API endpoints
│   └── config/
│       ├── __init__.py
│       └── settings.py             # Configuration
├── tests/
├── requirements.txt
└── README.md
```

### Step 4.2: Create the MLflow Registry Client

Create `src/registry/mlflow_registry.py`:

```python
"""
MLflow Model Registry Client
Handles all interactions with MLflow's Model Registry
"""
import os
import mlflow
from mlflow.tracking import MlflowClient
from mlflow.exceptions import MlflowException
from typing import Dict, List, Optional, Any
import logging

logger = logging.getLogger(__name__)


class MLflowRegistryClient:
    """
    Client for interacting with MLflow Model Registry.
    
    This class wraps MLflow's client to provide a cleaner interface
    and handle errors gracefully.
    """
    
    def __init__(self, tracking_uri: Optional[str] = None):
        """
        Initialize the MLflow registry client.
        
        Args:
            tracking_uri: MLflow tracking server URI. 
                          Defaults to MLFLOW_TRACKING_URI env var.
        """
        self.tracking_uri = tracking_uri or os.getenv(
            "MLFLOW_TRACKING_URI", 
            "http://localhost:5500"
        )
        mlflow.set_tracking_uri(self.tracking_uri)
        self.client = MlflowClient(tracking_uri=self.tracking_uri)
        logger.info(f"Initialized MLflow client with URI: {self.tracking_uri}")
    
    def register_model(
        self,
        model_uri: str,
        model_name: str,
        tags: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        Register a model in the Model Registry.
        
        Args:
            model_uri: URI of the logged model (e.g., "runs:/run-id/model")
            model_name: Name to register the model under
            tags: Optional tags to add to the model
            
        Returns:
            Dictionary with model version information
        """
        try:
            # Register the model
            model_version = mlflow.register_model(
                model_uri=model_uri,
                name=model_name
            )
            
            # Add tags if provided
            if tags:
                for key, value in tags.items():
                    self.client.set_model_version_tag(
                        name=model_name,
                        version=model_version.version,
                        key=key,
                        value=str(value)
                    )
            
            logger.info(
                f"Registered model '{model_name}' version {model_version.version}"
            )
            
            return {
                "name": model_name,
                "version": model_version.version,
                "run_id": model_version.run_id,
                "status": model_version.status,
                "creation_timestamp": model_version.creation_timestamp
            }
            
        except MlflowException as e:
            logger.error(f"Failed to register model: {e}")
            raise
    
    def get_model_version(
        self,
        model_name: str,
        version: Optional[int] = None,
        stage: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get information about a specific model version.
        
        Args:
            model_name: Name of the model
            version: Specific version number (optional)
            stage: Stage name like "Production" or "Staging" (optional)
            
        Returns:
            Dictionary with model version information
        """
        try:
            if stage:
                # Get model version by stage
                model_version = self.client.get_latest_versions(
                    name=model_name,
                    stages=[stage]
                )[0]
            elif version:
                # Get specific version
                model_version = self.client.get_model_version(
                    name=model_name,
                    version=str(version)
                )
            else:
                # Get latest version
                model_version = self.client.get_latest_versions(
                    name=model_name
                )[0]
            
            return {
                "name": model_name,
                "version": model_version.version,
                "stage": model_version.current_stage,
                "run_id": model_version.run_id,
                "status": model_version.status,
                "creation_timestamp": model_version.creation_timestamp,
                "tags": dict(model_version.tags) if model_version.tags else {}
            }
            
        except (MlflowException, IndexError) as e:
            logger.error(f"Failed to get model version: {e}")
            raise
    
    def list_model_versions(
        self,
        model_name: str
    ) -> List[Dict[str, Any]]:
        """
        List all versions of a model.
        
        Args:
            model_name: Name of the model
            
        Returns:
            List of dictionaries with version information
        """
        try:
            versions = self.client.search_model_versions(f"name='{model_name}'")
            
            return [
                {
                    "version": v.version,
                    "stage": v.current_stage,
                    "run_id": v.run_id,
                    "status": v.status,
                    "creation_timestamp": v.creation_timestamp,
                    "tags": dict(v.tags) if v.tags else {}
                }
                for v in versions
            ]
            
        except MlflowException as e:
            logger.error(f"Failed to list model versions: {e}")
            raise
    
    def transition_model_stage(
        self,
        model_name: str,
        version: int,
        stage: str,
        archive_existing_versions: bool = False
    ) -> Dict[str, Any]:
        """
        Transition a model version to a new stage.
        
        Args:
            model_name: Name of the model
            version: Version number to transition
            stage: Target stage ("Staging", "Production", "Archived")
            archive_existing_versions: If True, archive existing versions in the target stage
            
        Returns:
            Dictionary with updated model version information
        """
        try:
            # Archive existing versions if requested
            if archive_existing_versions and stage in ["Staging", "Production"]:
                existing = self.client.get_latest_versions(
                    name=model_name,
                    stages=[stage]
                )
                for existing_version in existing:
                    self.client.transition_model_version_stage(
                        name=model_name,
                        version=existing_version.version,
                        stage="Archived"
                    )
            
            # Transition to new stage
            self.client.transition_model_version_stage(
                name=model_name,
                version=str(version),
                stage=stage
            )
            
            logger.info(
                f"Transitioned {model_name} v{version} to {stage}"
            )
            
            return self.get_model_version(model_name, version=version)
            
        except MlflowException as e:
            logger.error(f"Failed to transition model stage: {e}")
            raise
    
    def load_model(
        self,
        model_name: str,
        version: Optional[int] = None,
        stage: Optional[str] = None
    ) -> Any:
        """
        Load a model from the registry.
        
        Args:
            model_name: Name of the model
            version: Specific version (optional)
            stage: Stage name like "Production" (optional)
            
        Returns:
            Loaded model object
        """
        try:
            if stage:
                model_uri = f"models:/{model_name}/{stage}"
            elif version:
                model_uri = f"models:/{model_name}/{version}"
            else:
                model_uri = f"models:/{model_name}/latest"
            
            # Try to load as sklearn model first
            try:
                import mlflow.sklearn
                return mlflow.sklearn.load_model(model_uri)
            except:
                pass
            
            # Try PyTorch
            try:
                import mlflow.pytorch
                return mlflow.pytorch.load_model(model_uri)
            except:
                pass
            
            # Try TensorFlow
            try:
                import mlflow.tensorflow
                return mlflow.tensorflow.load_model(model_uri)
            except:
                pass
            
            # Fallback to pyfunc
            return mlflow.pyfunc.load_model(model_uri)
            
        except MlflowException as e:
            logger.error(f"Failed to load model: {e}")
            raise
    
    def delete_model_version(
        self,
        model_name: str,
        version: int
    ) -> bool:
        """
        Delete a model version from the registry.
        
        Args:
            model_name: Name of the model
            version: Version number to delete
            
        Returns:
            True if successful
        """
        try:
            self.client.delete_model_version(
                name=model_name,
                version=str(version)
            )
            logger.info(f"Deleted {model_name} v{version}")
            return True
            
        except MlflowException as e:
            logger.error(f"Failed to delete model version: {e}")
            raise
```

### Step 4.3: Create the Model Service (Business Logic Layer)

Create `src/registry/model_service.py`:

```python
"""
Model Service
Business logic layer for model registry operations
"""
from typing import Dict, List, Optional, Any
import logging
from .mlflow_registry import MLflowRegistryClient

logger = logging.getLogger(__name__)


class ModelService:
    """
    Service layer for model registry operations.
    
    This class adds business logic on top of the MLflow client,
    such as validation, approval workflows, and metadata management.
    """
    
    def __init__(self, registry_client: Optional[MLflowRegistryClient] = None):
        """
        Initialize the model service.
        
        Args:
            registry_client: Optional MLflowRegistryClient instance.
                            If None, creates a new one.
        """
        self.registry = registry_client or MLflowRegistryClient()
    
    def register_model_from_run(
        self,
        run_id: str,
        model_name: str,
        artifact_path: str = "model",
        tags: Optional[Dict[str, str]] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Register a model from an MLflow run.
        
        Args:
            run_id: MLflow run ID
            model_name: Name to register the model under
            artifact_path: Path to model artifact in the run
            tags: Tags to add to the model version
            metadata: Additional metadata to store
            
        Returns:
            Dictionary with registration information
        """
        model_uri = f"runs:/{run_id}/{artifact_path}"
        
        # Combine tags and metadata
        all_tags = tags or {}
        if metadata:
            all_tags.update({f"metadata.{k}": str(v) for k, v in metadata.items()})
        
        result = self.registry.register_model(
            model_uri=model_uri,
            model_name=model_name,
            tags=all_tags
        )
        
        logger.info(
            f"Registered model '{model_name}' v{result['version']} from run {run_id}"
        )
        
        return result
    
    def promote_to_staging(
        self,
        model_name: str,
        version: int,
        archive_existing: bool = True
    ) -> Dict[str, Any]:
        """
        Promote a model version to Staging.
        
        Args:
            model_name: Name of the model
            version: Version to promote
            archive_existing: Whether to archive existing staging versions
            
        Returns:
            Updated model version information
        """
        return self.registry.transition_model_stage(
            model_name=model_name,
            version=version,
            stage="Staging",
            archive_existing_versions=archive_existing
        )
    
    def promote_to_production(
        self,
        model_name: str,
        version: int,
        archive_existing: bool = True,
        require_staging: bool = True
    ) -> Dict[str, Any]:
        """
        Promote a model version to Production.
        
        Args:
            model_name: Name of the model
            version: Version to promote
            archive_existing: Whether to archive existing production versions
            require_staging: Whether the model must be in Staging first
            
        Returns:
            Updated model version information
        """
        # Validate that model is in Staging if required
        if require_staging:
            current_version = self.registry.get_model_version(
                model_name=model_name,
                version=version
            )
            if current_version["stage"] != "Staging":
                raise ValueError(
                    f"Model must be in Staging before promotion to Production. "
                    f"Current stage: {current_version['stage']}"
                )
        
        return self.registry.transition_model_stage(
            model_name=model_name,
            version=version,
            stage="Production",
            archive_existing_versions=archive_existing
        )
    
    def get_production_model(
        self,
        model_name: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get the current production model.
        
        Args:
            model_name: Name of the model
            
        Returns:
            Model version information or None if no production model exists
        """
        try:
            return self.registry.get_model_version(
                model_name=model_name,
                stage="Production"
            )
        except Exception as e:
            logger.warning(f"No production model found for {model_name}: {e}")
            return None
    
    def get_staging_model(
        self,
        model_name: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get the current staging model.
        
        Args:
            model_name: Name of the model
            
        Returns:
            Model version information or None if no staging model exists
        """
        try:
            return self.registry.get_model_version(
                model_name=model_name,
                stage="Staging"
            )
        except Exception as e:
            logger.warning(f"No staging model found for {model_name}: {e}")
            return None
    
    def list_models(self) -> List[str]:
        """
        List all registered model names.
        
        Returns:
            List of model names
        """
        from mlflow.tracking import MlflowClient
        client = MlflowClient()
        models = client.search_registered_models()
        return [model.name for model in models]
    
    def get_model_history(
        self,
        model_name: str
    ) -> List[Dict[str, Any]]:
        """
        Get full version history for a model.
        
        Args:
            model_name: Name of the model
            
        Returns:
            List of all versions, sorted by version number (newest first)
        """
        versions = self.registry.list_model_versions(model_name)
        return sorted(versions, key=lambda x: int(x["version"]), reverse=True)
    
    def compare_versions(
        self,
        model_name: str,
        version1: int,
        version2: int
    ) -> Dict[str, Any]:
        """
        Compare two model versions.
        
        Args:
            model_name: Name of the model
            version1: First version to compare
            version2: Second version to compare
            
        Returns:
            Dictionary with comparison information
        """
        v1_info = self.registry.get_model_version(model_name, version=version1)
        v2_info = self.registry.get_model_version(model_name, version=version2)
        
        # Get run information to compare metrics
        from mlflow.tracking import MlflowClient
        client = MlflowClient()
        
        run1 = client.get_run(v1_info["run_id"])
        run2 = client.get_run(v2_info["run_id"])
        
        return {
            "version1": {
                "version": v1_info["version"],
                "stage": v1_info["stage"],
                "metrics": run1.data.metrics,
                "params": run1.data.params
            },
            "version2": {
                "version": v2_info["version"],
                "stage": v2_info["stage"],
                "metrics": run2.data.metrics,
                "params": run2.data.params
            }
        }
```

### Step 4.4: Test Your Service

Create `test_registry_service.py`:

```python
from src.registry.model_service import ModelService
from src.registry.mlflow_registry import MLflowRegistryClient
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import make_classification
import os

# Initialize
mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5500"))
mlflow.set_experiment("test-registry-service")

# Train and log a model
with mlflow.start_run():
    X, y = make_classification(n_samples=100, n_features=10, random_state=42)
    model = RandomForestClassifier(n_estimators=10, random_state=42)
    model.fit(X, y)
    
    mlflow.sklearn.log_model(model, "model")
    run_id = mlflow.active_run().info.run_id

# Test the service
service = ModelService()

# Register the model
result = service.register_model_from_run(
    run_id=run_id,
    model_name="test-model",
    tags={"team": "ai", "purpose": "testing"}
)

print(f"Registered: {result}")

# Get the model
model_info = service.registry.get_model_version("test-model", version=result["version"])
print(f"Model info: {model_info}")

# Promote to staging
staging_info = service.promote_to_staging("test-model", result["version"])
print(f"Promoted to staging: {staging_info}")
```

Run it to verify everything works!

---

## Step 5: Model Lifecycle Management

### Understanding the Lifecycle

A model goes through these stages:

```
Development → Registered → Staging → Production → Archived
```

### Step 5.1: Create Lifecycle Management Functions

Add to `src/registry/model_service.py`:

```python
    def archive_old_versions(
        self,
        model_name: str,
        keep_latest_n: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Archive old model versions, keeping only the latest N.
        
        Args:
            model_name: Name of the model
            keep_latest_n: Number of recent versions to keep
            
        Returns:
            List of archived versions
        """
        versions = self.get_model_history(model_name)
        
        # Sort by version number (newest first)
        sorted_versions = sorted(
            versions,
            key=lambda x: int(x["version"]),
            reverse=True
        )
        
        # Archive versions beyond keep_latest_n
        archived = []
        for version_info in sorted_versions[keep_latest_n:]:
            if version_info["stage"] not in ["Production", "Staging"]:
                try:
                    self.registry.transition_model_stage(
                        model_name=model_name,
                        version=int(version_info["version"]),
                        stage="Archived"
                    )
                    archived.append(version_info)
                except Exception as e:
                    logger.warning(f"Failed to archive version {version_info['version']}: {e}")
        
        return archived
    
    def get_model_health(
        self,
        model_name: str,
        version: Optional[int] = None,
        stage: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get health status of a model version.
        
        Args:
            model_name: Name of the model
            version: Specific version (optional)
            stage: Stage name (optional)
            
        Returns:
            Dictionary with health information
        """
        model_info = self.registry.get_model_version(
            model_name=model_name,
            version=version,
            stage=stage
        )
        
        # Get run information
        from mlflow.tracking import MlflowClient
        client = MlflowClient()
        run = client.get_run(model_info["run_id"])
        
        import time
        return {
            "name": model_name,
            "version": model_info["version"],
            "stage": model_info["stage"],
            "status": model_info["status"],
            "has_metrics": len(run.data.metrics) > 0,
            "has_params": len(run.data.params) > 0,
            "creation_timestamp": model_info["creation_timestamp"],
            "age_days": (time.time() - model_info["creation_timestamp"] / 1000) / 86400
        }
```

### Step 5.2: Create Approval Workflow

For production systems, you often want approval before promoting models. Create `src/registry/approval_workflow.py`:

```python
"""
Model Approval Workflow
Manages approval process for model promotions
"""
from typing import Dict, Optional, List
import logging
from datetime import datetime
from .model_service import ModelService

logger = logging.getLogger(__name__)


class ApprovalWorkflow:
    """
    Manages approval workflow for model promotions.
    
    In a real system, this would integrate with your user management
    and notification systems.
    """
    
    def __init__(self, model_service: ModelService):
        self.service = model_service
        self.pending_approvals = {}  # In production, use a database
    
    def request_staging_promotion(
        self,
        model_name: str,
        version: int,
        requested_by: str,
        reason: str
    ) -> Dict[str, Any]:
        """
        Request promotion to Staging.
        
        Args:
            model_name: Name of the model
            version: Version to promote
            requested_by: User requesting the promotion
            reason: Reason for promotion
            
        Returns:
            Approval request information
        """
        # Validate model exists
        model_info = self.service.registry.get_model_version(
            model_name=model_name,
            version=version
        )
        
        request_id = f"{model_name}-v{version}-staging"
        
        approval_request = {
            "request_id": request_id,
            "model_name": model_name,
            "version": version,
            "target_stage": "Staging",
            "requested_by": requested_by,
            "reason": reason,
            "status": "pending",
            "created_at": datetime.utcnow().isoformat(),
            "approved_by": None,
            "approved_at": None
        }
        
        self.pending_approvals[request_id] = approval_request
        
        logger.info(
            f"Staging promotion requested: {model_name} v{version} by {requested_by}"
        )
        
        return approval_request
    
    def request_production_promotion(
        self,
        model_name: str,
        version: int,
        requested_by: str,
        reason: str,
        require_approvers: int = 1
    ) -> Dict[str, Any]:
        """
        Request promotion to Production.
        
        Args:
            model_name: Name of the model
            version: Version to promote
            requested_by: User requesting the promotion
            reason: Reason for promotion
            require_approvers: Number of approvals needed
            
        Returns:
            Approval request information
        """
        # Validate model is in Staging
        model_info = self.service.registry.get_model_version(
            model_name=model_name,
            version=version
        )
        
        if model_info["stage"] != "Staging":
            raise ValueError(
                f"Model must be in Staging before Production promotion. "
                f"Current stage: {model_info['stage']}"
            )
        
        request_id = f"{model_name}-v{version}-production"
        
        approval_request = {
            "request_id": request_id,
            "model_name": model_name,
            "version": version,
            "target_stage": "Production",
            "requested_by": requested_by,
            "reason": reason,
            "status": "pending",
            "require_approvers": require_approvers,
            "approvers": [],
            "created_at": datetime.utcnow().isoformat()
        }
        
        self.pending_approvals[request_id] = approval_request
        
        logger.info(
            f"Production promotion requested: {model_name} v{version} by {requested_by}"
        )
        
        return approval_request
    
    def approve_promotion(
        self,
        request_id: str,
        approved_by: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Approve a promotion request.
        
        Args:
            request_id: ID of the approval request
            approved_by: User approving the request
            notes: Optional approval notes
            
        Returns:
            Updated approval request
        """
        if request_id not in self.pending_approvals:
            raise ValueError(f"Approval request not found: {request_id}")
        
        request = self.pending_approvals[request_id]
        
        if request["status"] != "pending":
            raise ValueError(f"Request is not pending: {request['status']}")
        
        # Add approver
        if "approvers" not in request:
            request["approvers"] = []
        
        request["approvers"].append({
            "user": approved_by,
            "notes": notes,
            "approved_at": datetime.utcnow().isoformat()
        })
        
        # Check if enough approvals
        required = request.get("require_approvers", 1)
        if len(request["approvers"]) >= required:
            # Execute promotion
            if request["target_stage"] == "Staging":
                self.service.promote_to_staging(
                    model_name=request["model_name"],
                    version=request["version"]
                )
            elif request["target_stage"] == "Production":
                self.service.promote_to_production(
                    model_name=request["model_name"],
                    version=request["version"]
                )
            
            request["status"] = "approved"
            request["approved_by"] = approved_by
            request["approved_at"] = datetime.utcnow().isoformat()
            
            logger.info(
                f"Promotion approved and executed: {request_id} by {approved_by}"
            )
        
        return request
    
    def reject_promotion(
        self,
        request_id: str,
        rejected_by: str,
        reason: str
    ) -> Dict[str, Any]:
        """
        Reject a promotion request.
        
        Args:
            request_id: ID of the approval request
            rejected_by: User rejecting the request
            reason: Reason for rejection
            
        Returns:
            Updated approval request
        """
        if request_id not in self.pending_approvals:
            raise ValueError(f"Approval request not found: {request_id}")
        
        request = self.pending_approvals[request_id]
        request["status"] = "rejected"
        request["rejected_by"] = rejected_by
        request["rejection_reason"] = reason
        request["rejected_at"] = datetime.utcnow().isoformat()
        
        logger.info(f"Promotion rejected: {request_id} by {rejected_by}")
        
        return request
```

---

## Step 6: Integration with Training Pipelines

### Connecting Training to Registry

Now that you have a registry service, you need to integrate it with your training pipelines. This ensures every trained model is automatically registered.

### Step 6.1: Create Training Integration

Create `src/integrations/training_integration.py`:

```python
"""
Training Pipeline Integration
Automatically registers models after training
"""
import mlflow
from typing import Dict, Optional, Any
import logging
from ..registry.model_service import ModelService

logger = logging.getLogger(__name__)


class TrainingIntegration:
    """
    Integrates model training with the registry.
    
    Use this in your training scripts to automatically
    register models after training.
    """
    
    def __init__(self, model_service: Optional[ModelService] = None):
        self.service = model_service or ModelService()
        self.current_run_id = None
    
    def start_training_run(
        self,
        experiment_name: str,
        run_name: Optional[str] = None,
        tags: Optional[Dict[str, str]] = None
    ):
        """
        Start an MLflow run for training.
        
        Args:
            experiment_name: Name of the experiment
            run_name: Optional name for this run
            tags: Tags to add to the run
        """
        mlflow.set_experiment(experiment_name)
        self.run = mlflow.start_run(run_name=run_name, tags=tags)
        self.current_run_id = self.run.info.run_id
        logger.info(f"Started training run: {self.current_run_id}")
        return self.run
    
    def log_training_metrics(
        self,
        metrics: Dict[str, float],
        step: Optional[int] = None
    ):
        """
        Log training metrics.
        
        Args:
            metrics: Dictionary of metric names to values
            step: Optional step number (for iterative training)
        """
        mlflow.log_metrics(metrics, step=step)
    
    def log_training_params(
        self,
        params: Dict[str, Any]
    ):
        """
        Log training parameters.
        
        Args:
            params: Dictionary of parameter names to values
        """
        mlflow.log_params(params)
    
    def register_trained_model(
        self,
        model_name: str,
        artifact_path: str = "model",
        tags: Optional[Dict[str, str]] = None,
        metadata: Optional[Dict[str, Any]] = None,
        auto_promote_to_staging: bool = False
    ) -> Dict[str, Any]:
        """
        Register a trained model in the registry.
        
        Args:
            model_name: Name to register the model under
            artifact_path: Path to model in the run artifacts
            tags: Tags to add to the model version
            metadata: Additional metadata
            auto_promote_to_staging: Whether to automatically promote to Staging
            
        Returns:
            Registration information
        """
        if not self.current_run_id:
            raise ValueError("No active training run. Call start_training_run() first.")
        
        # Register the model
        result = self.service.register_model_from_run(
            run_id=self.current_run_id,
            model_name=model_name,
            artifact_path=artifact_path,
            tags=tags,
            metadata=metadata
        )
        
        # Auto-promote if requested
        if auto_promote_to_staging:
            self.service.promote_to_staging(
                model_name=model_name,
                version=result["version"]
            )
            result["stage"] = "Staging"
        
        logger.info(
            f"Registered trained model: {model_name} v{result['version']}"
        )
        
        return result
    
    def end_training_run(self):
        """End the current training run."""
        if self.run:
            mlflow.end_run()
            self.current_run_id = None
```

### Step 6.2: Example Training Script with Integration

Create `examples/train_with_registry.py`:

```python
"""
Example training script with automatic model registration
"""
from src.integrations.training_integration import TrainingIntegration
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score
from sklearn.datasets import make_classification
import os

# Initialize MLflow
mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5500"))

# Initialize training integration
training = TrainingIntegration()

# Start training run
training.start_training_run(
    experiment_name="sentiment-classification",
    run_name="rf-baseline-v1",
    tags={"team": "nlp", "model_type": "random_forest"}
)

try:
    # Prepare data
    X, y = make_classification(n_samples=1000, n_features=20, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Log data information
    training.log_training_params({
        "train_samples": len(X_train),
        "test_samples": len(X_test),
        "n_features": X.shape[1]
    })
    
    # Train model
    model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    training.log_training_params({
        "n_estimators": 100,
        "max_depth": 10,
        "random_state": 42
    })
    
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, average='weighted')
    recall = recall_score(y_test, y_pred, average='weighted')
    
    # Log metrics
    training.log_training_metrics({
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall
    })
    
    # Log model to MLflow
    import mlflow.sklearn
    mlflow.sklearn.log_model(model, "model")
    
    # Register in model registry
    registration = training.register_trained_model(
        model_name="sentiment-classifier",
        tags={
            "accuracy": str(accuracy),
            "framework": "sklearn"
        },
        metadata={
            "training_data_version": "v1.0",
            "feature_count": X.shape[1]
        },
        auto_promote_to_staging=True  # Automatically promote to staging
    )
    
    print(f"Training complete!")
    print(f"Model registered: {registration['name']} v{registration['version']}")
    print(f"Stage: {registration.get('stage', 'None')}")
    
finally:
    # Always end the run
    training.end_training_run()
```

---

## Step 7: Model Serving and Deployment

### Loading Models for Inference

Once models are in the registry, you need to load them for serving predictions.

### Step 7.1: Create Model Loader Service

Create `src/serving/model_loader.py`:

```python
"""
Model Loader Service
Loads models from registry for serving
"""
import os
import logging
from typing import Optional, Any, Dict
from ..registry.model_service import ModelService
import mlflow

logger = logging.getLogger(__name__)


class ModelLoader:
    """
    Service for loading models from the registry for inference.
    
    This class handles caching, error handling, and model reloading.
    """
    
    def __init__(self, model_service: Optional[ModelService] = None):
        self.service = model_service or ModelService()
        self.model_cache = {}  # In production, use Redis or similar
    
    def load_production_model(
        self,
        model_name: str,
        use_cache: bool = True
    ) -> Any:
        """
        Load the production version of a model.
        
        Args:
            model_name: Name of the model
            use_cache: Whether to use cached model if available
            
        Returns:
            Loaded model object
        """
        cache_key = f"{model_name}:production"
        
        # Check cache
        if use_cache and cache_key in self.model_cache:
            logger.debug(f"Loading {model_name} from cache")
            return self.model_cache[cache_key]
        
        # Load from registry
        try:
            model = self.service.registry.load_model(
                model_name=model_name,
                stage="Production"
            )
            
            # Cache it
            if use_cache:
                self.model_cache[cache_key] = model
            
            logger.info(f"Loaded production model: {model_name}")
            return model
            
        except Exception as e:
            logger.error(f"Failed to load production model {model_name}: {e}")
            raise
    
    def load_staging_model(
        self,
        model_name: str
    ) -> Any:
        """
        Load the staging version of a model.
        
        Args:
            model_name: Name of the model
            
        Returns:
            Loaded model object
        """
        try:
            model = self.service.registry.load_model(
                model_name=model_name,
                stage="Staging"
            )
            logger.info(f"Loaded staging model: {model_name}")
            return model
            
        except Exception as e:
            logger.error(f"Failed to load staging model {model_name}: {e}")
            raise
    
    def load_specific_version(
        self,
        model_name: str,
        version: int
    ) -> Any:
        """
        Load a specific model version.
        
        Args:
            model_name: Name of the model
            version: Version number
            
        Returns:
            Loaded model object
        """
        try:
            model = self.service.registry.load_model(
                model_name=model_name,
                version=version
            )
            logger.info(f"Loaded {model_name} v{version}")
            return model
            
        except Exception as e:
            logger.error(f"Failed to load {model_name} v{version}: {e}")
            raise
    
    def reload_production_model(
        self,
        model_name: str
    ) -> Any:
        """
        Force reload of production model (clears cache).
        
        Args:
            model_name: Name of the model
            
        Returns:
            Reloaded model object
        """
        cache_key = f"{model_name}:production"
        if cache_key in self.model_cache:
            del self.model_cache[cache_key]
        
        return self.load_production_model(model_name, use_cache=False)
    
    def clear_cache(self):
        """Clear the model cache."""
        self.model_cache.clear()
        logger.info("Model cache cleared")
```

### Step 7.2: Create Prediction Service

Create `src/serving/prediction_service.py`:

```python
"""
Prediction Service
Handles model predictions with error handling and logging
"""
import logging
from typing import Any, Dict, Optional, List
import numpy as np
from .model_loader import ModelLoader

logger = logging.getLogger(__name__)


class PredictionService:
    """
    Service for making predictions using registered models.
    
    Handles preprocessing, prediction, postprocessing, and error handling.
    """
    
    def __init__(self, model_loader: Optional[ModelLoader] = None):
        self.loader = model_loader or ModelLoader()
        self.prediction_history = []  # In production, use a database
    
    def predict(
        self,
        model_name: str,
        data: Any,
        use_staging: bool = False,
        version: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Make a prediction using a registered model.
        
        Args:
            model_name: Name of the model to use
            data: Input data for prediction
            use_staging: Whether to use staging model instead of production
            version: Specific version to use (overrides use_staging)
            
        Returns:
            Dictionary with prediction and metadata
        """
        try:
            # Load model
            if version:
                model = self.loader.load_specific_version(model_name, version)
                stage = f"v{version}"
            elif use_staging:
                model = self.loader.load_staging_model(model_name)
                stage = "staging"
            else:
                model = self.loader.load_production_model(model_name)
                stage = "production"
            
            # Make prediction
            # Handle different input formats
            if isinstance(data, list):
                predictions = model.predict(data)
            elif isinstance(data, np.ndarray):
                predictions = model.predict(data)
            else:
                # Assume single prediction
                predictions = model.predict([data])[0]
            
            result = {
                "model_name": model_name,
                "stage": stage,
                "prediction": predictions.tolist() if hasattr(predictions, 'tolist') else predictions,
                "status": "success"
            }
            
            # Log prediction (in production, send to monitoring system)
            self._log_prediction(model_name, stage, data, result)
            
            return result
            
        except Exception as e:
            logger.error(f"Prediction failed for {model_name}: {e}")
            return {
                "model_name": model_name,
                "status": "error",
                "error": str(e)
            }
    
    def batch_predict(
        self,
        model_name: str,
        data: List[Any],
        use_staging: bool = False
    ) -> Dict[str, Any]:
        """
        Make batch predictions.
        
        Args:
            model_name: Name of the model
            data: List of input data
            use_staging: Whether to use staging model
            
        Returns:
            Dictionary with predictions
        """
        try:
            model = (self.loader.load_staging_model(model_name) 
                    if use_staging 
                    else self.loader.load_production_model(model_name))
            
            predictions = model.predict(data)
            
            return {
                "model_name": model_name,
                "predictions": predictions.tolist() if hasattr(predictions, 'tolist') else predictions,
                "count": len(predictions),
                "status": "success"
            }
            
        except Exception as e:
            logger.error(f"Batch prediction failed for {model_name}: {e}")
            return {
                "model_name": model_name,
                "status": "error",
                "error": str(e)
            }
    
    def _log_prediction(
        self,
        model_name: str,
        stage: str,
        input_data: Any,
        result: Dict[str, Any]
    ):
        """Log prediction for monitoring."""
        from datetime import datetime
        # In production, send to your monitoring system
        self.prediction_history.append({
            "model_name": model_name,
            "stage": stage,
            "timestamp": datetime.utcnow().isoformat(),
            "input_shape": str(np.array(input_data).shape) if hasattr(input_data, '__len__') else "scalar",
            "success": result["status"] == "success"
        })
        
        # Keep only last 1000 predictions in memory
        if len(self.prediction_history) > 1000:
            self.prediction_history = self.prediction_history[-1000:]
```

### Step 7.3: Create REST API

Create `src/api/routes.py`:

```python
"""
REST API Routes for Model Registry
"""
from flask import Flask, request, jsonify
from typing import Dict, Any
import logging
from ..registry.model_service import ModelService
from ..serving.prediction_service import PredictionService

logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize services
model_service = ModelService()
prediction_service = PredictionService()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "service": "model-registry"})


@app.route('/models', methods=['GET'])
def list_models():
    """List all registered models."""
    try:
        models = model_service.list_models()
        return jsonify({"models": models})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/models/<model_name>/versions', methods=['GET'])
def list_versions(model_name: str):
    """List all versions of a model."""
    try:
        versions = model_service.get_model_history(model_name)
        return jsonify({"model_name": model_name, "versions": versions})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/models/<model_name>/production', methods=['GET'])
def get_production_model(model_name: str):
    """Get current production model information."""
    try:
        model_info = model_service.get_production_model(model_name)
        if not model_info:
            return jsonify({"error": "No production model found"}), 404
        return jsonify(model_info)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/models/<model_name>/predict', methods=['POST'])
def predict(model_name: str):
    """Make a prediction using the production model."""
    try:
        data = request.get_json()
        if not data or "data" not in data:
            return jsonify({"error": "Missing 'data' field"}), 400
        
        result = prediction_service.predict(
            model_name=model_name,
            data=data["data"],
            use_staging=data.get("use_staging", False),
            version=data.get("version")
        )
        
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/models/<model_name>/versions/<int:version>/promote', methods=['POST'])
def promote_model(model_name: str, version: int):
    """Promote a model version to a new stage."""
    try:
        data = request.get_json() or {}
        stage = data.get("stage", "Staging")
        
        if stage == "Staging":
            result = model_service.promote_to_staging(model_name, version)
        elif stage == "Production":
            result = model_service.promote_to_production(model_name, version)
        else:
            return jsonify({"error": f"Invalid stage: {stage}"}), 400
        
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

---

## Step 8: Advanced Features

### A/B Testing

Implement A/B testing to compare model versions:

```python
import random
from typing import Dict, Any

class ABTestService:
    """Service for managing A/B tests between model versions."""
    
    def __init__(self, model_service: ModelService):
        self.service = model_service
        self.active_tests = {}
    
    def start_ab_test(
        self,
        model_name: str,
        version_a: int,
        version_b: int,
        traffic_split: float = 0.5,
        user_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Start an A/B test.
        
        Args:
            model_name: Name of the model
            version_a: First version to test
            version_b: Second version to test
            traffic_split: Percentage of traffic to version B (0.0-1.0)
            user_id: Optional user ID for consistent assignment
        """
        from datetime import datetime
        test_id = f"{model_name}-{version_a}-vs-{version_b}"
        
        self.active_tests[test_id] = {
            "model_name": model_name,
            "version_a": version_a,
            "version_b": version_b,
            "traffic_split": traffic_split,
            "started_at": datetime.utcnow().isoformat()
        }
        
        return {"test_id": test_id, "status": "active"}
    
    def get_model_for_request(
        self,
        test_id: str,
        user_id: Optional[str] = None
    ) -> int:
        """
        Get which model version to use for a request.
        
        Uses consistent hashing if user_id is provided.
        """
        test = self.active_tests.get(test_id)
        if not test:
            raise ValueError(f"Test not found: {test_id}")
        
        if user_id:
            # Consistent assignment based on user ID
            hash_value = hash(user_id) % 100
            threshold = test["traffic_split"] * 100
            version = test["version_b"] if hash_value < threshold else test["version_a"]
        else:
            # Random assignment
            version = (test["version_b"] 
                      if random.random() < test["traffic_split"] 
                      else test["version_a"])
        
        return version
```

### Model Monitoring Integration

Add monitoring to track model performance:

```python
class ModelMonitor:
    """Monitor model performance in production."""
    
    def __init__(self):
        self.metrics = {}  # In production, use time-series database
    
    def record_prediction(
        self,
        model_name: str,
        version: int,
        prediction: Any,
        actual: Optional[Any] = None,
        latency_ms: float = 0.0
    ):
        """Record a prediction for monitoring."""
        key = f"{model_name}:v{version}"
        
        if key not in self.metrics:
            self.metrics[key] = {
                "predictions": 0,
                "errors": 0,
                "total_latency": 0.0,
                "correct": 0,
                "total": 0
            }
        
        metrics = self.metrics[key]
        metrics["predictions"] += 1
        metrics["total_latency"] += latency_ms
        
        if actual is not None:
            metrics["total"] += 1
            if prediction == actual:
                metrics["correct"] += 1
    
    def get_performance(
        self,
        model_name: str,
        version: int
    ) -> Dict[str, Any]:
        """Get performance metrics for a model version."""
        key = f"{model_name}:v{version}"
        metrics = self.metrics.get(key, {})
        
        if metrics.get("predictions", 0) == 0:
            return {"status": "no_data"}
        
        return {
            "predictions": metrics["predictions"],
            "errors": metrics["errors"],
            "avg_latency_ms": metrics["total_latency"] / metrics["predictions"],
            "accuracy": (metrics["correct"] / metrics["total"] 
                        if metrics["total"] > 0 else None)
        }
```

---

## Step 9: Production Best Practices

### Security

1. **Authentication**: Add authentication to your API endpoints
2. **Authorization**: Control who can promote models to production
3. **Secrets Management**: Store MLflow credentials securely
4. **Audit Logging**: Log all model registry operations

### Performance

1. **Model Caching**: Cache loaded models to avoid repeated loads
2. **Lazy Loading**: Load models only when needed
3. **Connection Pooling**: Reuse MLflow client connections
4. **Async Operations**: Use async/await for non-blocking operations

### Reliability

1. **Error Handling**: Handle MLflow connection failures gracefully
2. **Retry Logic**: Retry failed operations with exponential backoff
3. **Health Checks**: Monitor MLflow server health
4. **Fallback Models**: Keep previous production model available if new one fails

### Monitoring

1. **Model Metrics**: Track prediction accuracy, latency, error rates
2. **Data Drift**: Monitor input data distribution changes
3. **Model Drift**: Detect when model performance degrades
4. **Alerts**: Set up alerts for critical issues

---

## Troubleshooting

### Common Issues

**Issue: Cannot connect to MLflow**

```
Error: Connection refused
```

**Solution**:**
1. Check MLflow container is running: `docker ps | grep mlflow`
2. Verify MLFLOW_TRACKING_URI is correct
3. Check network connectivity: `curl http://localhost:5500`

**Issue: Model registration fails**

```
Error: Model not found at URI
```

**Solution**:
1. Verify the run_id exists
2. Check the artifact_path is correct
3. Ensure the model was logged in the run

**Issue: Cannot load model**

```
Error: No model found in stage Production
```

**Solution**:
1. Check if model is registered: Use MLflow UI
2. Verify stage name is correct (case-sensitive)
3. Ensure model was promoted to that stage

**Issue: Model performance degrades**

**Solution**:
1. Check for data drift
2. Compare current metrics to baseline
3. Consider rolling back to previous version
4. Retrain with new data

---

## Next Steps

Now that you have a complete model registry implementation:

1. **Integrate with CI/CD**: Automatically register models after training
2. **Add Monitoring**: Set up alerts for model performance
3. **Implement A/B Testing**: Compare model versions in production
4. **Add Approval Workflows**: Require approvals for production promotions
5. **Scale Up**: Move to production infrastructure (Kubernetes, etc.)

## Conclusion

You've built a complete MLflow Model Registry implementation that:
- Tracks all model versions
- Manages model lifecycle (Staging → Production → Archived)
- Provides a clean API for model operations
- Integrates with training pipelines
- Supports model serving and deployment
- Includes advanced features like A/B testing

This foundation can scale to handle hundreds of models and thousands of versions, providing the infrastructure needed for production machine learning operations.

