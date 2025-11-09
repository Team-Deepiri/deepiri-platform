"""
Multi-Armed Bandit Tests
Test bandit selection and learning
"""
import pytest
import numpy as np
from app.services.bandit_service import MultiArmedBandit, BanditService


class TestMultiArmedBandit:
    """Test multi-armed bandit."""
    
    def test_bandit_initialization(self):
        """Test bandit initialization."""
        challenge_types = ['quiz', 'puzzle', 'coding_challenge']
        bandit = MultiArmedBandit(challenge_types)
        
        assert len(bandit.challenge_types) == 3
        assert all(ct in bandit.alpha for ct in challenge_types)
    
    def test_challenge_selection(self):
        """Test challenge selection."""
        bandit = MultiArmedBandit(['quiz', 'puzzle'])
        context = np.array([0.5, 0.6, 0.7, 0.8, 0.9, 0.5, 0.6, 0.7, 0.8, 0.9])
        
        selected = bandit.select_challenge(context)
        assert selected in bandit.challenge_types
        assert bandit.counts[selected] > 0
    
    def test_bandit_update(self):
        """Test bandit update with reward."""
        bandit = MultiArmedBandit(['quiz', 'puzzle'])
        context = np.ones(10) * 0.5
        
        initial_alpha = bandit.alpha['quiz'].copy()
        bandit.update('quiz', 0.8, context)
        
        assert np.any(bandit.alpha['quiz'] > initial_alpha)
    
    def test_bandit_statistics(self):
        """Test bandit statistics."""
        bandit = MultiArmedBandit(['quiz', 'puzzle'])
        context = np.ones(10) * 0.5
        
        for _ in range(10):
            selected = bandit.select_challenge(context)
            bandit.update(selected, 0.7, context)
        
        stats = bandit.get_statistics()
        assert stats['total_pulls'] == 10
        assert sum(stats['counts'].values()) == 10


class TestBanditService:
    """Test bandit service."""
    
    @pytest.fixture
    def service(self):
        return BanditService()
    
    @pytest.mark.asyncio
    async def test_select_challenge(self, service):
        """Test challenge selection via service."""
        context = {
            'performance': 0.7,
            'engagement': 0.8,
            'time_of_day': 0.5,
            'energy_level': 0.6
        }
        
        challenge_type = await service.select_challenge('user123', context)
        assert challenge_type in ['quiz', 'puzzle', 'coding_challenge', 'timed_completion', 'streak']
    
    @pytest.mark.asyncio
    async def test_update_bandit(self, service):
        """Test bandit update via service."""
        context = {'performance': 0.7, 'engagement': 0.8}
        
        await service.update_bandit('user123', 'quiz', 0.8, context)
        
        bandit = service.get_bandit('user123')
        assert bandit.counts['quiz'] > 0

