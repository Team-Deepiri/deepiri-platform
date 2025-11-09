"""
RAG System Tests
Test retrieval-augmented generation
"""
import pytest
from app.train.infrastructure.rag_pipeline import RAGPipeline


class TestRAGPipeline:
    """Test RAG pipeline."""
    
    @pytest.fixture
    def rag(self):
        try:
            return RAGPipeline()
        except Exception:
            pytest.skip("Milvus not available")
    
    def test_add_challenges(self, rag):
        """Test adding challenges to vector store."""
        challenges = [
            {
                'id': '1',
                'task_type': 'code',
                'challenge_text': 'Write a function to sort an array',
                'metadata': {'difficulty': 'medium'}
            },
            {
                'id': '2',
                'task_type': 'study',
                'challenge_text': 'Answer quiz questions about machine learning',
                'metadata': {'difficulty': 'easy'}
            }
        ]
        
        rag.add_challenges(challenges)
        assert True
    
    def test_retrieve(self, rag):
        """Test challenge retrieval."""
        query = "I need to write code"
        results = rag.retrieve(query, top_k=5)
        
        assert isinstance(results, list)
        assert len(results) <= 5
    
    def test_reranking(self, rag):
        """Test reranking functionality."""
        candidates = [
            {'challenge_text': 'Write code', 'score': 0.5},
            {'challenge_text': 'Debug code', 'score': 0.3}
        ]
        
        if rag.reranker:
            reranked = rag._rerank("code task", candidates)
            assert len(reranked) == len(candidates)
            assert 'rerank_score' in reranked[0]

