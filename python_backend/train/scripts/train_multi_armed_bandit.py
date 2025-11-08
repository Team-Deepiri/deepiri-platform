"""
Multi-Armed Bandit Training for Challenge Selection
ML Engineer 1: Train models for optimal challenge selection
"""
import numpy as np
from typing import Dict, List, Tuple
import json
from pathlib import Path

class MultiArmedBandit:
    """Multi-armed bandit for challenge selection."""
    
    def __init__(self, challenge_types: List[str], exploration_rate: float = 0.1):
        self.challenge_types = challenge_types
        self.exploration_rate = exploration_rate
        self.counts = {ct: 0 for ct in challenge_types}
        self.values = {ct: 0.0 for ct in challenge_types}
        self.rewards_history = {ct: [] for ct in challenge_types}
    
    def select_challenge(self, user_context: Dict) -> str:
        """
        Select challenge using epsilon-greedy strategy.
        
        Args:
            user_context: User's current context (performance, preferences, etc.)
            
        Returns:
            Selected challenge type
        """
        if np.random.random() < self.exploration_rate:
            return np.random.choice(self.challenge_types)
        else:
            return max(self.values, key=self.values.get)
    
    def update(self, challenge_type: str, reward: float):
        """Update bandit with reward."""
        self.counts[challenge_type] += 1
        n = self.counts[challenge_type]
        value = self.values[challenge_type]
        
        self.values[challenge_type] = ((n - 1) / n) * value + (1 / n) * reward
        self.rewards_history[challenge_type].append(reward)
    
    def train(self, training_data: List[Dict]):
        """
        Train bandit on historical data.
        
        Training data format:
        [
            {
                'challenge_type': 'quiz',
                'reward': 0.8,
                'user_context': {...}
            },
            ...
        ]
        """
        print(f"Training Multi-Armed Bandit on {len(training_data)} samples...")
        
        for sample in training_data:
            challenge_type = sample['challenge_type']
            reward = sample['reward']
            self.update(challenge_type, reward)
        
        print("Training complete!")
        print(f"Challenge values: {self.values}")
        print(f"Challenge counts: {self.counts}")
    
    def save_model(self, path: str):
        """Save trained model."""
        model_data = {
            'challenge_types': self.challenge_types,
            'exploration_rate': self.exploration_rate,
            'counts': self.counts,
            'values': self.values,
            'rewards_history': {k: v[-100:] for k, v in self.rewards_history.items()}
        }
        
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'w') as f:
            json.dump(model_data, f, indent=2)
        
        print(f"Model saved to {path}")
    
    def load_model(self, path: str):
        """Load trained model."""
        with open(path, 'r') as f:
            model_data = json.load(f)
        
        self.challenge_types = model_data['challenge_types']
        self.exploration_rate = model_data['exploration_rate']
        self.counts = model_data['counts']
        self.values = {k: float(v) for k, v in model_data['values'].items()}
        self.rewards_history = model_data.get('rewards_history', {})
        
        print(f"Model loaded from {path}")


def train_bandit_model():
    """Main training function."""
    print("=" * 60)
    print("Multi-Armed Bandit Training")
    print("=" * 60)
    
    challenge_types = ['quiz', 'puzzle', 'coding_challenge', 'timed_completion', 'streak']
    bandit = MultiArmedBandit(challenge_types, exploration_rate=0.1)
    
    print("\n1. Load training data from train/data/bandit_training.jsonl")
    print("2. Train bandit on historical challenge performance")
    print("3. Evaluate on validation set")
    print("4. Save model to train/models/bandit/")
    
    print("\nExample training data:")
    print(json.dumps({
        'challenge_type': 'quiz',
        'reward': 0.85,
        'user_context': {
            'user_id': '123',
            'performance': 0.8,
            'engagement': 0.9
        }
    }, indent=2))
    
    print("\nNext steps:")
    print("- ML Engineer 1: Implement full training pipeline")
    print("- Data Engineer: Prepare challenge performance datasets")
    print("- AI Systems Engineer: Integrate into challenge service")


if __name__ == "__main__":
    train_bandit_model()

