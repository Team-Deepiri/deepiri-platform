"""
Full Pipeline Integration Tests
Test complete AI pipeline end-to-end
"""
import pytest
import asyncio
from app.services.task_classifier import get_task_classifier
from app.services.challenge_generator import get_challenge_generator
from app.services.hybrid_ai_service import get_hybrid_service
from app.services.bandit_service import get_bandit_service


class TestFullPipeline:
    """Test complete AI pipeline."""
    
    @pytest.mark.asyncio
    async def test_task_to_challenge_pipeline(self):
        """Test complete task to challenge pipeline."""
        task_text = "Write a Python function to sort a list"
        
        classifier = get_task_classifier()
        classification = await classifier.classify_task(task_text)
        
        assert classification['type'] == 'code'
        
        generator = get_challenge_generator()
        task_dict = {
            'title': task_text,
            'type': classification['type'],
            'estimatedDuration': classification['estimated_duration']
        }
        
        challenge = await generator.generate_challenge(task_dict)
        
        assert 'type' in challenge
        assert 'title' in challenge
        assert 'pointsReward' in challenge
    
    @pytest.mark.asyncio
    async def test_hybrid_pipeline(self):
        """Test hybrid AI pipeline."""
        service = get_hybrid_service()
        
        task_text = "Study machine learning"
        classification = await service.classify_task_hybrid(task_text)
        
        assert 'type' in classification
        
        task = {'title': task_text, 'type': classification['type']}
        challenge = await service.generate_challenge_hybrid(task)
        
        assert 'type' in challenge
    
    @pytest.mark.asyncio
    async def test_bandit_selection_pipeline(self):
        """Test bandit-based challenge selection."""
        bandit_service = get_bandit_service()
        
        context = {
            'performance': 0.7,
            'engagement': 0.8,
            'time_of_day': 0.5
        }
        
        challenge_type = await bandit_service.select_challenge('user123', context)
        
        assert challenge_type in ['quiz', 'puzzle', 'coding_challenge', 'timed_completion', 'streak']
        
        await bandit_service.update_bandit('user123', challenge_type, 0.8, context)
        
        stats = bandit_service.get_bandit('user123').get_statistics()
        assert stats['total_pulls'] > 0

