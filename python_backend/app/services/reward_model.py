"""
Reward Model Service
RLHF-style reward model for challenge quality scoring
"""
import torch
import torch.nn as nn
from typing import Dict, List
import numpy as np
from ..logging_config import get_logger

logger = get_logger("service.reward")


class RewardModel(nn.Module):
    """Reward model for challenge quality."""
    
    def __init__(self, input_dim: int = 384, hidden_dim: int = 256):
        super(RewardModel, self).__init__()
        self.fc1 = nn.Linear(input_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim // 2)
        self.fc3 = nn.Linear(hidden_dim // 2, 1)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.1)
    
    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.relu(self.fc2(x))
        x = self.dropout(x)
        x = torch.sigmoid(self.fc3(x))
        return x


class RewardModelService:
    """Service for reward model inference."""
    
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path
        self.model = None
        self._load_model()
    
    def _load_model(self):
        """Load reward model."""
        if self.model_path:
            try:
                self.model = RewardModel()
                self.model.load_state_dict(torch.load(self.model_path))
                self.model.eval()
                logger.info("Reward model loaded", path=self.model_path)
            except Exception as e:
                logger.error("Reward model loading failed", error=str(e))
    
    def score_challenge(self, challenge_embedding: np.ndarray) -> float:
        """Score challenge quality."""
        if self.model is None:
            return 0.5
        
        with torch.no_grad():
            tensor = torch.FloatTensor(challenge_embedding).unsqueeze(0)
            score = self.model(tensor).item()
        
        return score
    
    def rank_challenges(self, challenges: List[Dict], embeddings: np.ndarray) -> List[Dict]:
        """Rank challenges by reward score."""
        scores = [self.score_challenge(emb) for emb in embeddings]
        
        ranked = sorted(
            zip(challenges, scores),
            key=lambda x: x[1],
            reverse=True
        )
        
        return [{"challenge": c, "reward_score": s} for c, s in ranked]

