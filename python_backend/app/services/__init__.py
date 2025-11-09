"""AI Services for Deepiri"""
from .task_classifier import TaskClassifier, get_task_classifier
from .challenge_generator import ChallengeGenerator, get_challenge_generator
from .context_aware_adaptation import ContextAwareAdapter, get_context_adapter
from .multimodal_understanding import MultimodalTaskUnderstanding, get_multimodal_understanding
from .neuro_symbolic_challenge import NeuroSymbolicChallengeGenerator, get_neuro_symbolic_generator
from .advanced_task_parser import AdvancedTaskParser, get_advanced_task_parser
from .adaptive_challenge_generator import AdaptiveChallengeGenerator, get_adaptive_challenge_generator
from .hybrid_ai_service import HybridAIService, get_hybrid_ai_service
from .reward_model import RewardModelService, get_reward_model
from .embedding_service import EmbeddingService, get_embedding_service
from .inference_service import InferenceService, get_inference_service

__all__ = [
    # Standard services
    'TaskClassifier',
    'get_task_classifier',
    'ChallengeGenerator',
    'get_challenge_generator',
    'ContextAwareAdapter',
    'get_context_adapter',
    'MultimodalTaskUnderstanding',
    'get_multimodal_understanding',
    'NeuroSymbolicChallengeGenerator',
    'get_neuro_symbolic_generator',
    # Advanced services
    'AdvancedTaskParser',
    'get_advanced_task_parser',
    'AdaptiveChallengeGenerator',
    'get_adaptive_challenge_generator',
    # Supporting services
    'HybridAIService',
    'get_hybrid_ai_service',
    'RewardModelService',
    'get_reward_model',
    'EmbeddingService',
    'get_embedding_service',
    'InferenceService',
    'get_inference_service'
]
