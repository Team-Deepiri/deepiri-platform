"""
Challenge Generator Tests
Comprehensive tests for challenge generation
"""
import pytest
from app.services.challenge_generator import ChallengeGenerator, get_challenge_generator


class TestChallengeGenerator:
    """Test challenge generation service."""
    
    @pytest.fixture
    def generator(self):
        return get_challenge_generator()
    
    @pytest.mark.asyncio
    async def test_generate_challenge(self, generator):
        """Test basic challenge generation."""
        task = {
            'title': 'Write a report',
            'description': 'Research and write comprehensive report',
            'type': 'creative',
            'estimatedDuration': 60
        }
        
        challenge = await generator.generate_challenge(task)
        
        assert 'type' in challenge
        assert 'title' in challenge
        assert 'description' in challenge
        assert 'difficulty' in challenge
        assert 'pointsReward' in challenge
        assert challenge['pointsReward'] > 0
    
    @pytest.mark.asyncio
    async def test_adaptive_difficulty(self, generator):
        """Test adaptive difficulty adjustment."""
        task = {'title': 'Task', 'type': 'code'}
        
        high_performance_history = {'average_performance': 0.9}
        low_performance_history = {'average_performance': 0.3}
        
        challenge_high = await generator.generate_challenge(task, high_performance_history)
        challenge_low = await generator.generate_challenge(task, low_performance_history)
        
        high_score = generator._difficulty_to_score(challenge_high['difficulty'])
        low_score = generator._difficulty_to_score(challenge_low['difficulty'])
        
        assert high_score >= low_score
    
    @pytest.mark.asyncio
    async def test_challenge_types(self, generator):
        """Test different challenge types."""
        task_types = ['study', 'code', 'creative', 'manual']
        
        for task_type in task_types:
            task = {'title': 'Test', 'type': task_type}
            challenge = await generator.generate_challenge(task)
            
            assert challenge['type'] in generator.CHALLENGE_TYPES
    
    @pytest.mark.asyncio
    async def test_points_calculation(self, generator):
        """Test points calculation."""
        task = {'title': 'Task', 'type': 'code'}
        classification = {'complexity': 'hard', 'estimated_duration': 90}
        
        points = generator._calculate_points('hard', classification)
        assert points >= 500
        
        points_easy = generator._calculate_points('easy', classification)
        assert points > points_easy


@pytest.mark.asyncio
async def test_generator_performance():
    """Performance test for generator."""
    generator = get_challenge_generator()
    
    import time
    start = time.time()
    
    for _ in range(5):
        await generator.generate_challenge({'title': 'Test', 'type': 'manual'})
    
    duration = time.time() - start
    avg_latency = duration / 5
    
    assert avg_latency < 5.0, f"Average latency {avg_latency}s exceeds 5s threshold"

