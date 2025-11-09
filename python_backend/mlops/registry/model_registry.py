"""
Model Registry Service
Manages model versioning, metadata, and lifecycle
"""
import os
import json
import shutil
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime
import mlflow
from mlflow.tracking import MlflowClient
from ..logging_config import get_logger

logger = get_logger("mlops.model_registry")


class ModelRegistry:
    """
    Model registry for:
    - Model versioning
    - Metadata management
    - Stage management (staging, production, archived)
    - A/B testing configuration
    """
    
    def __init__(self):
        self.mlflow_tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
        mlflow.set_tracking_uri(self.mlflow_tracking_uri)
        self.client = MlflowClient(tracking_uri=self.mlflow_tracking_uri)
        self.registry_path = Path(os.getenv("MODEL_REGISTRY_PATH", "model_registry"))
        self.registry_path.mkdir(exist_ok=True)
    
    def register_model(
        self,
        model_name: str,
        model_path: str,
        metadata: Dict,
        version: Optional[str] = None
    ) -> str:
        """
        Register model in registry.
        
        Returns:
            Model version
        """
        try:
            logger.info("Registering model", model_name=model_name)
            
            # Create model directory
            model_dir = self.registry_path / model_name
            model_dir.mkdir(exist_ok=True)
            
            # Generate version if not provided
            if version is None:
                version = self._generate_version(model_name)
            
            version_dir = model_dir / version
            version_dir.mkdir(exist_ok=True)
            
            # Copy model files
            if os.path.exists(model_path):
                shutil.copytree(model_path, version_dir / "model", dirs_exist_ok=True)
            
            # Save metadata
            metadata_file = version_dir / "metadata.json"
            metadata['version'] = version
            metadata['registered_at'] = datetime.utcnow().isoformat()
            metadata['model_name'] = model_name
            
            with open(metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            # Register in MLflow
            try:
                mlflow.register_model(
                    model_uri=f"runs:/{metadata.get('run_id', 'latest')}/model",
                    name=model_name
                )
            except Exception as e:
                logger.warning("MLflow registration failed", error=str(e))
            
            logger.info("Model registered", model_name=model_name, version=version)
            return version
            
        except Exception as e:
            logger.error("Model registration failed", error=str(e))
            raise
    
    def get_model_version(self, model_name: str, version: str) -> Optional[Dict]:
        """Get model version information."""
        try:
            version_dir = self.registry_path / model_name / version
            if not version_dir.exists():
                return None
            
            metadata_file = version_dir / "metadata.json"
            if metadata_file.exists():
                with open(metadata_file, 'r') as f:
                    return json.load(f)
            
            return None
            
        except Exception as e:
            logger.error("Error getting model version", error=str(e))
            return None
    
    def list_model_versions(self, model_name: str) -> List[Dict]:
        """List all versions of a model."""
        try:
            model_dir = self.registry_path / model_name
            if not model_dir.exists():
                return []
            
            versions = []
            for version_dir in model_dir.iterdir():
                if version_dir.is_dir():
                    metadata = self.get_model_version(model_name, version_dir.name)
                    if metadata:
                        versions.append(metadata)
            
            # Sort by version (newest first)
            versions.sort(key=lambda x: x.get('registered_at', ''), reverse=True)
            return versions
            
        except Exception as e:
            logger.error("Error listing model versions", error=str(e))
            return []
    
    def promote_to_stage(
        self,
        model_name: str,
        version: str,
        stage: str
    ) -> bool:
        """
        Promote model to stage (staging, production, archived).
        
        Args:
            stage: 'staging', 'production', or 'archived'
        """
        try:
            valid_stages = ['staging', 'production', 'archived']
            if stage not in valid_stages:
                raise ValueError(f"Invalid stage: {stage}. Must be one of {valid_stages}")
            
            # Update metadata
            metadata = self.get_model_version(model_name, version)
            if not metadata:
                raise ValueError(f"Model version not found: {model_name}/{version}")
            
            metadata['stage'] = stage
            metadata['promoted_at'] = datetime.utcnow().isoformat()
            
            version_dir = self.registry_path / model_name / version
            metadata_file = version_dir / "metadata.json"
            with open(metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            # Update MLflow
            try:
                self.client.transition_model_version_stage(
                    name=model_name,
                    version=version,
                    stage=stage
                )
            except Exception as e:
                logger.warning("MLflow stage update failed", error=str(e))
            
            logger.info("Model promoted to stage", 
                       model_name=model_name, 
                       version=version, 
                       stage=stage)
            return True
            
        except Exception as e:
            logger.error("Error promoting model", error=str(e))
            return False
    
    def get_production_model(self, model_name: str) -> Optional[Dict]:
        """Get current production model."""
        versions = self.list_model_versions(model_name)
        for version in versions:
            if version.get('stage') == 'production':
                return version
        return None
    
    def setup_ab_test(
        self,
        model_name: str,
        version_a: str,
        version_b: str,
        traffic_split: float = 0.5
    ) -> Dict:
        """
        Setup A/B test between two model versions.
        
        Args:
            traffic_split: Percentage of traffic to version B (0.0-1.0)
        """
        try:
            if not (0.0 <= traffic_split <= 1.0):
                raise ValueError("traffic_split must be between 0.0 and 1.0")
            
            ab_config = {
                'model_name': model_name,
                'version_a': version_a,
                'version_b': version_b,
                'traffic_split': traffic_split,
                'created_at': datetime.utcnow().isoformat(),
                'active': True
            }
            
            # Save A/B test configuration
            ab_file = self.registry_path / model_name / "ab_test.json"
            with open(ab_file, 'w') as f:
                json.dump(ab_config, f, indent=2)
            
            logger.info("A/B test configured", 
                       model_name=model_name,
                       version_a=version_a,
                       version_b=version_b,
                       traffic_split=traffic_split)
            
            return ab_config
            
        except Exception as e:
            logger.error("Error setting up A/B test", error=str(e))
            raise
    
    def get_ab_test_config(self, model_name: str) -> Optional[Dict]:
        """Get active A/B test configuration."""
        try:
            ab_file = self.registry_path / model_name / "ab_test.json"
            if ab_file.exists():
                with open(ab_file, 'r') as f:
                    config = json.load(f)
                    if config.get('active', False):
                        return config
            return None
            
        except Exception as e:
            logger.error("Error getting A/B test config", error=str(e))
            return None
    
    def _generate_version(self, model_name: str) -> str:
        """Generate new version number."""
        versions = self.list_model_versions(model_name)
        if not versions:
            return "1.0.0"
        
        # Get latest version
        latest = versions[0].get('version', '1.0.0')
        
        # Increment patch version
        parts = latest.split('.')
        if len(parts) == 3:
            major, minor, patch = parts
            patch = str(int(patch) + 1)
            return f"{major}.{minor}.{patch}"
        else:
            return "1.0.0"


# Singleton instance
_registry = None

def get_model_registry() -> ModelRegistry:
    """Get singleton ModelRegistry instance."""
    global _registry
    if _registry is None:
        _registry = ModelRegistry()
    return _registry

