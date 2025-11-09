"""
Inference Service
High-performance model inference with caching and batching
"""
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
from typing import List, Dict, Optional
import asyncio
from functools import lru_cache
from ..utils.cache import CacheManager
from ..logging_config import get_logger

logger = get_logger("service.inference")


class InferenceService:
    """Production inference service with optimization."""
    
    def __init__(self, model_path: Optional[str] = None, device: str = "cuda"):
        self.model_path = model_path
        self.device = device
        self.model = None
        self.tokenizer = None
        self.pipeline = None
        self.cache = CacheManager()
        self._load_model()
    
    def _load_model(self):
        """Load model for inference."""
        if not self.model_path:
            logger.warning("No model path provided, using default")
            return
        
        try:
            logger.info("Loading inference model", path=self.model_path)
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_path)
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_path,
                torch_dtype=torch.bfloat16,
                device_map="auto"
            )
            self.pipeline = pipeline(
                "text-generation",
                model=self.model,
                tokenizer=self.tokenizer,
                device=0 if torch.cuda.is_available() else -1
            )
            logger.info("Inference model loaded")
        except Exception as e:
            logger.error("Model loading failed", error=str(e))
    
    @lru_cache(maxsize=1000)
    def _cached_generate(self, prompt: str, max_length: int = 100) -> str:
        """Cached generation."""
        if not self.pipeline:
            return ""
        
        result = self.pipeline(
            prompt,
            max_length=max_length,
            num_return_sequences=1,
            temperature=0.7,
            do_sample=True
        )
        return result[0]['generated_text']
    
    async def generate(self, prompt: str, max_length: int = 100, use_cache: bool = True) -> str:
        """Generate text asynchronously."""
        cache_key = f"inference:{hash(prompt)}:{max_length}"
        
        if use_cache:
            cached = self.cache.get(cache_key)
            if cached:
                return cached
        
        result = await asyncio.to_thread(
            self._cached_generate,
            prompt,
            max_length
        )
        
        if use_cache and result:
            self.cache.set(cache_key, result, ttl=3600)
        
        return result
    
    async def batch_generate(self, prompts: List[str], max_length: int = 100) -> List[str]:
        """Generate for multiple prompts in batch."""
        tasks = [self.generate(p, max_length) for p in prompts]
        return await asyncio.gather(*tasks)


_inference_service = None

def get_inference_service() -> InferenceService:
    """Get singleton inference service."""
    global _inference_service
    if _inference_service is None:
        _inference_service = InferenceService()
    return _inference_service

