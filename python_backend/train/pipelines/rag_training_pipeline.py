"""
RAG Training Pipeline
Train retrieval and generation components for production RAG
"""
from sentence_transformers import SentenceTransformer, InputExample, losses
from sentence_transformers.evaluation import InformationRetrievalEvaluator
from torch.utils.data import DataLoader
from typing import List, Dict
import json
from pathlib import Path
from ..infrastructure.rag_pipeline import RAGPipeline
from ..logging_config import get_logger

logger = get_logger("train.rag")


class RAGTrainingPipeline:
    """Train RAG components."""
    
    def __init__(self, config: Dict):
        self.config = config
        self.embedding_model = None
        self.reranker = None
    
    def train_embedding_model(self, train_examples: List[Dict], output_path: str):
        """Fine-tune embedding model for task/challenge retrieval."""
        logger.info("Training embedding model")
        
        base_model = self.config.get("embedding_model", "sentence-transformers/all-MiniLM-L6-v2")
        self.embedding_model = SentenceTransformer(base_model)
        
        examples = []
        for ex in train_examples:
            examples.append(InputExample(
                texts=[ex['query'], ex['challenge_text']],
                label=ex.get('relevance_score', 1.0)
            ))
        
        train_dataloader = DataLoader(examples, shuffle=True, batch_size=16)
        train_loss = losses.CosineSimilarityLoss(self.embedding_model)
        
        self.embedding_model.fit(
            train_objectives=[(train_dataloader, train_loss)],
            epochs=self.config.get("epochs", 3),
            output_path=output_path,
            warmup_steps=100,
            show_progress_bar=True
        )
        
        logger.info("Embedding model trained", output_path=output_path)
        return output_path
    
    def train_reranker(self, train_examples: List[Dict], output_path: str):
        """Train cross-encoder reranker."""
        from sentence_transformers import CrossEncoder
        
        logger.info("Training reranker")
        
        base_model = self.config.get("reranker_model", "cross-encoder/ms-marco-MiniLM-L-6-v2")
        self.reranker = CrossEncoder(base_model, num_labels=1)
        
        train_data = []
        for ex in train_examples:
            train_data.append([ex['query'], ex['challenge_text'], ex.get('relevance_score', 1.0)])
        
        self.reranker.fit(
            train_data,
            epochs=self.config.get("reranker_epochs", 3),
            output_path=output_path,
            show_progress_bar=True
        )
        
        logger.info("Reranker trained", output_path=output_path)
        return output_path
    
    def evaluate_rag_system(self, test_data: List[Dict], rag_pipeline: RAGPipeline):
        """Evaluate complete RAG system."""
        logger.info("Evaluating RAG system")
        
        correct = 0
        total = 0
        
        for test_case in test_data:
            query = test_case['query']
            expected_challenge = test_case['expected_challenge_id']
            
            results = rag_pipeline.retrieve(query, top_k=10)
            
            retrieved_ids = [r['challenge_id'] for r in results]
            if expected_challenge in retrieved_ids:
                correct += 1
            total += 1
        
        accuracy = correct / total if total > 0 else 0
        logger.info("RAG evaluation complete", accuracy=accuracy, total=total)
        
        return {"accuracy": accuracy, "total": total, "correct": correct}

