"""
Multi-Armed Bandit Training
Train contextual bandit for challenge selection
"""
import numpy as np
from typing import List, Dict, Optional
import json
from pathlib import Path
import pickle
from ..logging_config import get_logger

logger = get_logger("train.bandit")


class ContextualBandit:
    """Contextual multi-armed bandit with Thompson sampling."""
    
    def __init__(self, challenge_types: List[str], context_dim: int = 10):
        self.challenge_types = challenge_types
        self.context_dim = context_dim
        self.alpha = {ct: np.ones(context_dim) for ct in challenge_types}
        self.beta = {ct: np.ones(context_dim) for ct in challenge_types}
        self.counts = {ct: 0 for ct in challenge_types}
    
    def select_challenge(self, context: np.ndarray) -> str:
        """Select challenge using Thompson sampling."""
        if context.shape[0] != self.context_dim:
            context = np.pad(context, (0, max(0, self.context_dim - context.shape[0])))
            context = context[:self.context_dim]
        
        samples = {}
        for ct in self.challenge_types:
            samples[ct] = np.random.beta(self.alpha[ct], self.beta[ct])
        
        return max(samples, key=samples.get)
    
    def update(self, challenge_type: str, reward: float, context: np.ndarray):
        """Update bandit with reward."""
        if context.shape[0] != self.context_dim:
            context = np.pad(context, (0, max(0, self.context_dim - context.shape[0])))
            context = context[:self.context_dim]
        
        self.counts[challenge_type] += 1
        
        if reward > 0.5:
            self.alpha[challenge_type] += context
        else:
            self.beta[challenge_type] += context
    
    def train(self, training_data: List[Dict]):
        """Train bandit on historical data."""
        logger.info("Training contextual bandit", samples=len(training_data))
        
        for sample in training_data:
            challenge_type = sample['challenge_type']
            reward = sample['reward']
            context = np.array(sample.get('context', []))
            
            self.update(challenge_type, reward, context)
        
        logger.info("Bandit training complete")
    
    def save(self, path: str):
        """Save trained bandit."""
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'wb') as f:
            pickle.dump({
                'challenge_types': self.challenge_types,
                'context_dim': self.context_dim,
                'alpha': self.alpha,
                'beta': self.beta,
                'counts': self.counts
            }, f)
        logger.info("Bandit saved", path=path)
    
    def load(self, path: str):
        """Load trained bandit."""
        with open(path, 'rb') as f:
            data = pickle.load(f)
            self.challenge_types = data['challenge_types']
            self.context_dim = data['context_dim']
            self.alpha = data['alpha']
            self.beta = data['beta']
            self.counts = data['counts']
        logger.info("Bandit loaded", path=path)


def train_bandit_from_data(dataset_path: str, output_path: str):
    """Train bandit from dataset."""
    with open(dataset_path, 'r') as f:
        data = [json.loads(line) for line in f]
    
    challenge_types = list(set([d['challenge_type'] for d in data]))
    bandit = ContextualBandit(challenge_types)
    
    bandit.train(data)
    bandit.save(output_path)
    
    return bandit

