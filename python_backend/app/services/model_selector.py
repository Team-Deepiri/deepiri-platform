"""
Model Selector Service
Switch between local models and API keys dynamically
"""
from typing import Optional, Dict, Literal
from enum import Enum
import os
from ..logging_config import get_logger

logger = get_logger("service.model_selector")


class ModelType(Enum):
    LOCAL = "local"
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    HUGGINGFACE = "huggingface"


class ModelSelector:
    """Select and switch between different model backends."""
    
    def __init__(self):
        self.current_model_type = ModelType.OPENAI
        self.local_model_path = None
        self.api_keys = {}
        self._load_config()
    
    def _load_config(self):
        """Load model configuration."""
        self.local_model_path = os.getenv("LOCAL_MODEL_PATH")
        self.api_keys = {
            'openai': os.getenv("OPENAI_API_KEY"),
            'anthropic': os.getenv("ANTHROPIC_API_KEY"),
            'huggingface': os.getenv("HUGGINGFACE_API_KEY")
        }
        
        preferred = os.getenv("PREFERRED_MODEL_TYPE", "openai")
        if preferred == "local" and self.local_model_path:
            self.current_model_type = ModelType.LOCAL
        elif preferred in self.api_keys and self.api_keys[preferred]:
            self.current_model_type = ModelType(preferred)
    
    def set_model_type(self, model_type: ModelType):
        """Set active model type."""
        if model_type == ModelType.LOCAL and not self.local_model_path:
            logger.warning("Local model not configured, keeping current model")
            return False
        
        if model_type != ModelType.LOCAL and not self.api_keys.get(model_type.value):
            logger.warning(f"{model_type.value} API key not configured")
            return False
        
        self.current_model_type = model_type
        logger.info("Model type changed", model_type=model_type.value)
        return True
    
    def get_model_config(self) -> Dict:
        """Get current model configuration."""
        config = {
            'type': self.current_model_type.value,
            'available_types': []
        }
        
        if self.local_model_path:
            config['available_types'].append('local')
            config['local_model_path'] = self.local_model_path
        
        for key, value in self.api_keys.items():
            if value:
                config['available_types'].append(key)
        
        return config
    
    def should_use_local(self, task_complexity: str = "medium") -> bool:
        """Determine if local model should be used."""
        if not self.local_model_path:
            return False
        
        if self.current_model_type == ModelType.LOCAL:
            return True
        
        if task_complexity in ['easy', 'medium']:
            return True
        
        return False
    
    def get_api_key(self, model_type: Optional[ModelType] = None) -> Optional[str]:
        """Get API key for model type."""
        model_type = model_type or self.current_model_type
        
        if model_type == ModelType.LOCAL:
            return None
        
        return self.api_keys.get(model_type.value)


_model_selector = None

def get_model_selector() -> ModelSelector:
    """Get singleton model selector."""
    global _model_selector
    if _model_selector is None:
        _model_selector = ModelSelector()
    return _model_selector

