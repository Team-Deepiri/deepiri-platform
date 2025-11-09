"""
Multi-Armed Bandit Service
Production bandit for challenge selection
"""
import numpy as np
import json
from typing import Dict, List, Optional
from pathlib import Path
import pickle
from ..utils.cache import CacheManager
from ..logging_config import get_logger

logger = get_logger("service.bandit")


class MultiArmedBandit:
    """Thompson sampling multi-armed bandit."""
    
    def __init__(self, challenge_types: List[str], context_dim: int = 10):
        self.challenge_types = challenge_types
        self.context_dim = context_dim
        self.alpha = {ct: np.ones(context_dim) for ct in challenge_types}
        self.beta = {ct: np.ones(context_dim) for ct in challenge_types}
        self.counts = {ct: 0 for ct in challenge_types}
        self.total_pulls = 0
    
    def select_challenge(self, context: np.ndarray) -> str:
        """Select challenge using Thompson sampling."""
        if context.shape[0] != self.context_dim:
            context = np.pad(context, (0, max(0, self.context_dim - context.shape[0])))[:self.context_dim]
        
        samples = {}
        for ct in self.challenge_types:
            theta = np.random.beta(self.alpha[ct], self.beta[ct])
            samples[ct] = np.dot(theta, context)
        
        selected = max(samples, key=samples.get)
        self.counts[selected] += 1
        self.total_pulls += 1
        
        return selected
    
    def update(self, challenge_type: str, reward: float, context: np.ndarray):
        """Update bandit with reward."""
        if context.shape[0] != self.context_dim:
            context = np.pad(context, (0, max(0, self.context_dim - context.shape[0])))[:self.context_dim]
        
        if reward > 0.5:
            self.alpha[challenge_type] += context * reward
        else:
            self.beta[challenge_type] += context * (1 - reward)
    
    def get_statistics(self) -> Dict:
        """Get bandit statistics."""
        return {
            'challenge_types': self.challenge_types,
            'counts': self.counts,
            'total_pulls': self.total_pulls,
            'alpha': {k: v.tolist() for k, v in self.alpha.items()},
            'beta': {k: v.tolist() for k, v in self.beta.items()}
        }
    
    def save(self, path: str):
        """Save bandit state."""
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'wb') as f:
            pickle.dump(self.get_statistics(), f)
    
    def load(self, path: str):
        """Load bandit state."""
        with open(path, 'rb') as f:
            data = pickle.load(f)
            self.challenge_types = data['challenge_types']
            self.counts = data['counts']
            self.total_pulls = data['total_pulls']
            self.alpha = {k: np.array(v) for k, v in data['alpha'].items()}
            self.beta = {k: np.array(v) for k, v in data['beta'].items()}


class BanditService:
    """Service for bandit operations."""
    
    def __init__(self):
        self.bandits: Dict[str, MultiArmedBandit] = {}
        self.cache = CacheManager()
        self._initialize_default_bandit()
    
    def _initialize_default_bandit(self):
        """Initialize default bandit."""
        challenge_types = ['quiz', 'puzzle', 'coding_challenge', 'timed_completion', 'streak']
        self.bandits['default'] = MultiArmedBandit(challenge_types)
    
    def get_bandit(self, user_id: str) -> MultiArmedBandit:
        """Get or create bandit for user."""
        if user_id not in self.bandits:
            challenge_types = ['quiz', 'puzzle', 'coding_challenge', 'timed_completion', 'streak']
            self.bandits[user_id] = MultiArmedBandit(challenge_types)
        return self.bandits[user_id]
    
    async def select_challenge(self, user_id: str, context: Dict) -> str:
        """Select challenge for user."""
        bandit = self.get_bandit(user_id)
        context_array = self._context_to_array(context)
        return bandit.select_challenge(context_array)
    
    async def update_bandit(self, user_id: str, challenge_type: str, reward: float, context: Dict):
        """Update bandit with reward."""
        bandit = self.get_bandit(user_id)
        context_array = self._context_to_array(context)
        bandit.update(challenge_type, reward, context_array)
    
    def _context_to_array(self, context: Dict) -> np.ndarray:
        """Convert context dict to array."""
        features = [
            context.get('performance', 0.5),
            context.get('engagement', 0.5),
            context.get('time_of_day', 0.5),
            context.get('energy_level', 0.5),
            context.get('focus_score', 0.5),
            context.get('task_complexity', 0.5),
            context.get('recent_success_rate', 0.5),
            context.get('preferred_difficulty', 0.5),
            context.get('streak', 0.0),
            context.get('level', 1.0) / 100.0
        ]
        return np.array(features)


_bandit_service = None

def get_bandit_service() -> BanditService:
    """Get singleton bandit service."""
    global _bandit_service
    if _bandit_service is None:
        _bandit_service = BanditService()
    return _bandit_service

