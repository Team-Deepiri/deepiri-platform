"""
Embedding Service
Generate embeddings for RAG and semantic search
"""
from sentence_transformers import SentenceTransformer
from typing import List, Union
import numpy as np
from ..utils.cache import CacheManager
from ..logging_config import get_logger

logger = get_logger("service.embedding")


class EmbeddingService:
    """Production embedding service."""
    
    def __init__(self, model_name: str = "sentence-transformers/all-MiniLM-L6-v2"):
        self.model_name = model_name
        self.model = SentenceTransformer(model_name)
        self.cache = CacheManager()
        logger.info("Embedding service initialized", model=model_name)
    
    def embed(self, text: Union[str, List[str]], use_cache: bool = True) -> np.ndarray:
        """Generate embeddings."""
        if isinstance(text, str):
            text = [text]
        
        cache_key = f"embedding:{hash(''.join(text))}"
        
        if use_cache:
            cached = self.cache.get(cache_key)
            if cached:
                return np.array(cached)
        
        embeddings = self.model.encode(text, show_progress_bar=False)
        
        if use_cache:
            self.cache.set(cache_key, embeddings.tolist(), ttl=86400)
        
        return embeddings
    
    def similarity(self, text1: str, text2: str) -> float:
        """Compute similarity between two texts."""
        emb1 = self.embed([text1], use_cache=True)[0]
        emb2 = self.embed([text2], use_cache=True)[0]
        
        similarity = np.dot(emb1, emb2) / (np.linalg.norm(emb1) * np.linalg.norm(emb2))
        return float(similarity)
    
    def find_most_similar(self, query: str, candidates: List[str], top_k: int = 5) -> List[tuple]:
        """Find most similar candidates to query."""
        query_emb = self.embed([query], use_cache=True)[0]
        candidate_embs = self.embed(candidates, use_cache=True)
        
        similarities = np.dot(candidate_embs, query_emb)
        top_indices = np.argsort(similarities)[-top_k:][::-1]
        
        return [(candidates[i], float(similarities[i])) for i in top_indices]


_embedding_service = None

def get_embedding_service() -> EmbeddingService:
    """Get singleton embedding service."""
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service

