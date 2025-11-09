"""
Enhanced RAG Service
Pinecone/Weaviate integration with cross-modal retrieval
"""
import os
from typing import List, Dict, Optional
import numpy as np
from ..logging_config import get_logger
from .embedding_service import get_embedding_service

logger = get_logger("pyagent.enhanced_rag")


class EnhancedRAGService:
    """
    Enhanced RAG with:
    - Pinecone/Weaviate vector database
    - Cross-modal retrieval (text, images, code)
    - Semantic search with reranking
    - Incremental updates
    """
    
    def __init__(self):
        self.embedding_service = get_embedding_service()
        self.vector_db = None
        self._initialize_vector_db()
    
    def _initialize_vector_db(self):
        """Initialize vector database (Pinecone or Weaviate)."""
        try:
            # Try Pinecone first
            pinecone_key = os.getenv("PINECONE_API_KEY")
            if pinecone_key:
                import pinecone
                pinecone.init(api_key=pinecone_key, environment=os.getenv("PINECONE_ENVIRONMENT", "us-east1-gcp"))
                self.vector_db = "pinecone"
                logger.info("Pinecone initialized")
                return
            
            # Try Weaviate
            weaviate_url = os.getenv("WEAVIATE_URL")
            if weaviate_url:
                import weaviate
                self.vector_db = weaviate.Client(weaviate_url)
                logger.info("Weaviate initialized")
                return
            
            logger.warning("No vector database configured, using in-memory storage")
            self.vector_db = "memory"
            self.memory_store = []
            
        except Exception as e:
            logger.error("Vector DB initialization failed", error=str(e))
            self.vector_db = "memory"
            self.memory_store = []
    
    async def index_document(
        self,
        content: str,
        doc_id: str,
        metadata: Optional[Dict] = None,
        doc_type: str = "text"
    ):
        """Index document in vector database."""
        try:
            # Generate embedding
            embedding = await self.embedding_service.generate_embedding(content)
            
            if self.vector_db == "pinecone":
                await self._index_pinecone(doc_id, embedding, metadata or {})
            elif self.vector_db == "weaviate":
                await self._index_weaviate(doc_id, embedding, content, metadata or {})
            else:
                # Memory store
                self.memory_store.append({
                    'id': doc_id,
                    'embedding': embedding,
                    'content': content,
                    'metadata': metadata or {},
                    'type': doc_type
                })
            
            logger.info("Document indexed", doc_id=doc_id, type=doc_type)
            
        except Exception as e:
            logger.error("Error indexing document", doc_id=doc_id, error=str(e))
            raise
    
    async def search(
        self,
        query: str,
        top_k: int = 5,
        filters: Optional[Dict] = None,
        doc_types: Optional[List[str]] = None
    ) -> List[Dict]:
        """Search for similar documents."""
        try:
            # Generate query embedding
            query_embedding = await self.embedding_service.generate_embedding(query)
            
            if self.vector_db == "pinecone":
                results = await self._search_pinecone(query_embedding, top_k, filters)
            elif self.vector_db == "weaviate":
                results = await self._search_weaviate(query_embedding, top_k, filters)
            else:
                # Memory search
                results = self._search_memory(query_embedding, top_k, doc_types)
            
            # Rerank results
            reranked = await self._rerank_results(query, results)
            
            return reranked
            
        except Exception as e:
            logger.error("Error searching", error=str(e))
            return []
    
    async def _index_pinecone(self, doc_id: str, embedding: List[float], metadata: Dict):
        """Index in Pinecone."""
        import pinecone
        index = pinecone.Index(os.getenv("PINECONE_INDEX", "deepiri"))
        index.upsert([(doc_id, embedding, metadata)])
    
    async def _index_weaviate(self, doc_id: str, embedding: List[float], content: str, metadata: Dict):
        """Index in Weaviate."""
        self.vector_db.data_object.create(
            data_object={
                "content": content,
                **metadata
            },
            class_name="Document",
            vector=embedding
        )
    
    async def _search_pinecone(self, query_embedding: List[float], top_k: int, filters: Optional[Dict]):
        """Search Pinecone."""
        import pinecone
        index = pinecone.Index(os.getenv("PINECONE_INDEX", "deepiri"))
        results = index.query(
            vector=query_embedding,
            top_k=top_k,
            include_metadata=True,
            filter=filters
        )
        return [
            {
                'id': match.id,
                'score': match.score,
                'metadata': match.metadata
            }
            for match in results.matches
        ]
    
    async def _search_weaviate(self, query_embedding: List[float], top_k: int, filters: Optional[Dict]):
        """Search Weaviate."""
        query = self.vector_db.query.get("Document", ["content"]).with_near_vector({
            "vector": query_embedding
        }).with_limit(top_k)
        
        if filters:
            query = query.with_where(filters)
        
        results = query.do()
        return [
            {
                'id': result.get('_additional', {}).get('id'),
                'score': result.get('_additional', {}).get('certainty', 0),
                'content': result.get('content', ''),
                'metadata': {k: v for k, v in result.items() if k != 'content'}
            }
            for result in results.get('data', {}).get('Get', {}).get('Document', [])
        ]
    
    def _search_memory(self, query_embedding: List[float], top_k: int, doc_types: Optional[List[str]]):
        """Search in-memory store."""
        if not self.memory_store:
            return []
        
        # Filter by type if specified
        candidates = self.memory_store
        if doc_types:
            candidates = [d for d in candidates if d.get('type') in doc_types]
        
        # Calculate similarities
        similarities = []
        for doc in candidates:
            similarity = np.dot(query_embedding, doc['embedding']) / (
                np.linalg.norm(query_embedding) * np.linalg.norm(doc['embedding'])
            )
            similarities.append({
                'id': doc['id'],
                'score': float(similarity),
                'content': doc['content'],
                'metadata': doc['metadata']
            })
        
        # Sort by score and return top_k
        similarities.sort(key=lambda x: x['score'], reverse=True)
        return similarities[:top_k]
    
    async def _rerank_results(self, query: str, results: List[Dict]) -> List[Dict]:
        """Rerank results using cross-encoder (simplified)."""
        # In production, would use a cross-encoder model
        # For now, return results as-is
        return results
    
    async def delete_document(self, doc_id: str):
        """Delete document from index."""
        try:
            if self.vector_db == "pinecone":
                import pinecone
                index = pinecone.Index(os.getenv("PINECONE_INDEX", "deepiri"))
                index.delete(ids=[doc_id])
            elif self.vector_db == "weaviate":
                self.vector_db.data_object.delete(doc_id, class_name="Document")
            else:
                self.memory_store = [d for d in self.memory_store if d['id'] != doc_id]
            
            logger.info("Document deleted", doc_id=doc_id)
        except Exception as e:
            logger.error("Error deleting document", doc_id=doc_id, error=str(e))


# Singleton instance
_rag_service = None

def get_enhanced_rag_service() -> EnhancedRAGService:
    """Get singleton EnhancedRAGService instance."""
    global _rag_service
    if _rag_service is None:
        _rag_service = EnhancedRAGService()
    return _rag_service

