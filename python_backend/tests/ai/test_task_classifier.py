"""
Task Classifier Tests
Comprehensive tests for task classification
"""
import pytest
import asyncio
from app.services.task_classifier import TaskClassifier, get_task_classifier


class TestTaskClassifier:
    """Test task classification service."""
    
    @pytest.fixture
    def classifier(self):
        return get_task_classifier()
    
    @pytest.mark.asyncio
    async def test_classify_code_task(self, classifier):
        """Test classification of coding task."""
        result = await classifier.classify_task(
            "Fix bug in login system",
            "Debug authentication issue"
        )
        assert result['type'] == 'code'
        assert 'complexity' in result
        assert 'estimated_duration' in result
    
    @pytest.mark.asyncio
    async def test_classify_study_task(self, classifier):
        """Test classification of study task."""
        result = await classifier.classify_task(
            "Read chapter 5 of machine learning textbook"
        )
        assert result['type'] == 'study'
        assert result['complexity'] in ['easy', 'medium', 'hard', 'very_hard']
    
    @pytest.mark.asyncio
    async def test_classify_creative_task(self, classifier):
        """Test classification of creative task."""
        result = await classifier.classify_task(
            "Write a blog post about AI trends"
        )
        assert result['type'] == 'creative'
    
    @pytest.mark.asyncio
    async def test_batch_classification(self, classifier):
        """Test batch classification."""
        tasks = [
            {'title': 'Write code', 'description': 'Implement feature'},
            {'title': 'Study for exam', 'description': 'Review materials'}
        ]
        results = await classifier.batch_classify(tasks)
        assert len(results) == 2
        assert all('classification' in r for r in results)
    
    @pytest.mark.asyncio
    async def test_default_classification(self, classifier):
        """Test default classification when AI unavailable."""
        result = classifier._default_classification("Some random task")
        assert result['type'] in ['study', 'code', 'creative', 'manual', 'meeting', 'research', 'admin']
        assert 'complexity' in result
        assert 'estimated_duration' in result


@pytest.mark.asyncio
async def test_classifier_performance():
    """Performance test for classifier."""
    classifier = get_task_classifier()
    
    import time
    start = time.time()
    
    for _ in range(10):
        await classifier.classify_task("Test task")
    
    duration = time.time() - start
    avg_latency = duration / 10
    
    assert avg_latency < 2.0, f"Average latency {avg_latency}s exceeds 2s threshold"

