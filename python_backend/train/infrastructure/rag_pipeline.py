"""
Production RAG Pipeline for Challenge Generation
Retrieval-Augmented Generation with vector search, reranking, and context management
"""
from typing import List, Dict, Optional, Tuple
import numpy as np
from sentence_transformers import SentenceTransformer
from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType, utility
import json
from pathlib import Path
from ..logging_config import get_logger

logger = get_logger("rag.pipeline")


class RAGPipeline:
    """Production RAG system for challenge generation and task understanding."""
    
    def __init__(
        self,
        embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2",
        collection_name: str = "deepiri_challenges",
        milvus_host: str = "localhost",
        milvus_port: int = 19530
    ):
        self.embedding_model = SentenceTransformer(embedding_model)
        self.collection_name = collection_name
        self.milvus_host = milvus_host
        self.milvus_port = milvus_port
        self.collection = None
        self.reranker = None
        self._initialize_milvus()
        self._load_reranker()
    
    def _initialize_milvus(self):
        """Initialize Milvus connection and collection."""
        try:
            connections.connect(
                alias="default",
                host=self.milvus_host,
                port=self.milvus_port
            )
            
            if utility.has_collection(self.collection_name):
                self.collection = Collection(self.collection_name)
            else:
                self._create_collection()
            
            logger.info("Milvus connection established", collection=self.collection_name)
        except Exception as e:
            logger.error("Milvus initialization failed", error=str(e))
            raise
    
    def _create_collection(self):
        """Create Milvus collection schema."""
        fields = [
            FieldSchema(name="id", dtype=DataType.INT64, is_primary=True, auto_id=True),
            FieldSchema(name="challenge_id", dtype=DataType.VARCHAR, max_length=100),
            FieldSchema(name="task_type", dtype=DataType.VARCHAR, max_length=50),
            FieldSchema(name="challenge_text", dtype=DataType.VARCHAR, max_length=2000),
            FieldSchema(name="metadata", dtype=DataType.JSON),
            FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=384)
        ]
        
        schema = CollectionSchema(
            fields=fields,
            description="Deepiri challenge and task embeddings"
        )
        
        self.collection = Collection(
            name=self.collection_name,
            schema=schema
        )
        
        index_params = {
            "metric_type": "L2",
            "index_type": "HNSW",
            "params": {
                "M": 16,
                "efConstruction": 200
            }
        }
        
        self.collection.create_index(
            field_name="embedding",
            index_params=index_params
        )
        
        logger.info("Milvus collection created", collection=self.collection_name)
    
    def _load_reranker(self):
        """Load cross-encoder reranker for top-K refinement."""
        try:
            from sentence_transformers import CrossEncoder
            self.reranker = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
            logger.info("Reranker loaded")
        except Exception as e:
            logger.warning("Reranker not available", error=str(e))
    
    def add_challenges(self, challenges: List[Dict]):
        """Add challenge embeddings to vector store."""
        if not challenges:
            return
        
        texts = [c.get('challenge_text', '') for c in challenges]
        embeddings = self.embedding_model.encode(texts, show_progress_bar=True)
        
        entities = []
        for i, challenge in enumerate(challenges):
            entities.append({
                "challenge_id": challenge.get('id', str(i)),
                "task_type": challenge.get('task_type', 'manual'),
                "challenge_text": challenge.get('challenge_text', ''),
                "metadata": json.dumps(challenge.get('metadata', {})),
                "embedding": embeddings[i].tolist()
            })
        
        self.collection.insert(entities)
        self.collection.flush()
        
        logger.info("Challenges added to vector store", count=len(challenges))
    
    def retrieve(
        self,
        query: str,
        top_k: int = 10,
        task_type_filter: Optional[str] = None,
        rerank: bool = True
    ) -> List[Dict]:
        """Retrieve relevant challenges using semantic search."""
        query_embedding = self.embedding_model.encode([query])[0]
        
        search_params = {
            "metric_type": "L2",
            "params": {"ef": 64}
        }
        
        expr = None
        if task_type_filter:
            expr = f'task_type == "{task_type_filter}"'
        
        results = self.collection.search(
            data=[query_embedding.tolist()],
            anns_field="embedding",
            param=search_params,
            limit=top_k,
            expr=expr,
            output_fields=["challenge_id", "challenge_text", "task_type", "metadata"]
        )
        
        retrieved = []
        for hit in results[0]:
            retrieved.append({
                "challenge_id": hit.entity.get("challenge_id"),
                "challenge_text": hit.entity.get("challenge_text"),
                "task_type": hit.entity.get("task_type"),
                "metadata": json.loads(hit.entity.get("metadata", "{}")),
                "score": hit.distance
            })
        
        if rerank and self.reranker and len(retrieved) > 1:
            retrieved = self._rerank(query, retrieved)
        
        return retrieved
    
    def _rerank(self, query: str, candidates: List[Dict]) -> List[Dict]:
        """Rerank candidates using cross-encoder."""
        pairs = [[query, c["challenge_text"]] for c in candidates]
        scores = self.reranker.predict(pairs)
        
        for i, candidate in enumerate(candidates):
            candidate["rerank_score"] = float(scores[i])
        
        return sorted(candidates, key=lambda x: x["rerank_score"], reverse=True)
    
    def generate_with_rag(
        self,
        task: Dict,
        retrieved_challenges: List[Dict],
        base_llm_prompt: str
    ) -> Dict:
        """Generate challenge using RAG context."""
        context = "\n\n".join([
            f"Example {i+1}: {c['challenge_text']}"
            for i, c in enumerate(retrieved_challenges[:5])
        ])
        
        enhanced_prompt = f"""{base_llm_prompt}

Relevant Examples:
{context}

Task: {task.get('title', '')}
Description: {task.get('description', '')}

Generate a challenge similar in style to the examples above."""
        
        return {
            "prompt": enhanced_prompt,
            "context_challenges": retrieved_challenges,
            "context_count": len(retrieved_challenges)
        }


class RAGDataPipeline:
    """Pipeline for processing and indexing challenge data."""
    
    def __init__(self, rag_pipeline: RAGPipeline):
        self.rag = rag_pipeline
    
    def process_challenge_dataset(self, dataset_path: str):
        """Process and index challenge dataset."""
        with open(dataset_path, 'r') as f:
            challenges = [json.loads(line) for line in f]
        
        processed = []
        for challenge in challenges:
            processed.append({
                "id": challenge.get("id"),
                "task_type": challenge.get("task_type", "manual"),
                "challenge_text": self._create_challenge_text(challenge),
                "metadata": {
                    "difficulty": challenge.get("difficulty"),
                    "points": challenge.get("pointsReward"),
                    "duration": challenge.get("configuration", {}).get("timeLimit")
                }
            })
        
        self.rag.add_challenges(processed)
        logger.info("Dataset processed and indexed", count=len(processed))
    
    def _create_challenge_text(self, challenge: Dict) -> str:
        """Create searchable text from challenge."""
        parts = [
            challenge.get("title", ""),
            challenge.get("description", ""),
            challenge.get("type", ""),
            challenge.get("difficulty", "")
        ]
        return " ".join(filter(None, parts))


def initialize_rag_system():
    """Initialize production RAG system."""
    rag = RAGPipeline()
    return rag

