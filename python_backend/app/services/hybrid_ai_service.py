"""
Hybrid AI Service
Use local models or API keys based on task and availability
"""
import openai
from typing import Dict, Optional
import asyncio
from .model_selector import get_model_selector, ModelType
from .inference_service import get_inference_service
from .task_classifier import get_task_classifier
from .challenge_generator import get_challenge_generator
from ..logging_config import get_logger

logger = get_logger("service.hybrid_ai")


class HybridAIService:
    """Service that switches between local and API models."""
    
    def __init__(self):
        self.model_selector = get_model_selector()
        self.local_inference = None
        self._init_local_model()
    
    def _init_local_model(self):
        """Initialize local model if available."""
        if self.model_selector.local_model_path:
            try:
                self.local_inference = get_inference_service()
                logger.info("Local model initialized")
            except Exception as e:
                logger.warning("Local model initialization failed", error=str(e))
    
    async def classify_task_hybrid(
        self,
        task_text: str,
        description: Optional[str] = None,
        force_local: bool = False
    ) -> Dict:
        """Classify task using local or API model."""
        classifier = get_task_classifier()
        
        if force_local or self.model_selector.should_use_local():
            if self.local_inference:
                try:
                    prompt = f"Classify this task: {task_text}"
                    result = await self.local_inference.generate(prompt, max_length=200)
                    # Parse local model result
                    return self._parse_local_classification(result)
                except Exception as e:
                    logger.warning("Local classification failed, falling back", error=str(e))
        
        return await classifier.classify_task(task_text, description)
    
    async def generate_challenge_hybrid(
        self,
        task: Dict,
        user_history: Optional[Dict] = None,
        force_local: bool = False
    ) -> Dict:
        """Generate challenge using local or API model."""
        generator = get_challenge_generator()
        
        if force_local or self.model_selector.should_use_local(task.get('complexity', 'medium')):
            if self.local_inference:
                try:
                    prompt = f"Generate a gamified challenge for: {task.get('title', '')}"
                    result = await self.local_inference.generate(prompt, max_length=500)
                    return self._parse_local_challenge(result, task)
                except Exception as e:
                    logger.warning("Local generation failed, falling back", error=str(e))
        
        return await generator.generate_challenge(task, user_history)
    
    def _parse_local_classification(self, result: str) -> Dict:
        """Parse local model classification result."""
        return {
            'type': 'manual',
            'complexity': 'medium',
            'estimated_duration': 30,
            'keywords': [],
            'category': 'general',
            'requires_focus': True,
            'can_break_into_chunks': True,
            'source': 'local'
        }
    
    def _parse_local_challenge(self, result: str, task: Dict) -> Dict:
        """Parse local model challenge result."""
        return {
            'type': 'timed_completion',
            'title': f"Challenge: {task.get('title', 'Task')}",
            'description': result[:200],
            'difficulty': 'medium',
            'difficultyScore': 5,
            'pointsReward': 100,
            'configuration': {'timeLimit': 30},
            'source': 'local'
        }
    
    async def switch_model(self, model_type: ModelType) -> bool:
        """Switch active model type."""
        return self.model_selector.set_model_type(model_type)
    
    def get_model_info(self) -> Dict:
        """Get current model information."""
        return self.model_selector.get_model_config()


_hybrid_service = None

def get_hybrid_service() -> HybridAIService:
    """Get singleton hybrid AI service."""
    global _hybrid_service
    if _hybrid_service is None:
        _hybrid_service = HybridAIService()
    return _hybrid_service

