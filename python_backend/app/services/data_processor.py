"""
Data Processing Service
Process and transform data for training
"""
import pandas as pd
import numpy as np
from typing import List, Dict, Optional
import json
from pathlib import Path
from ..logging_config import get_logger

logger = get_logger("service.data")


class DataProcessor:
    """Process training data."""
    
    def process_task_data(self, raw_data: List[Dict]) -> pd.DataFrame:
        """Process raw task data into training format."""
        df = pd.DataFrame(raw_data)
        
        df['text'] = df['title'].fillna('') + ' ' + df['description'].fillna('')
        df['label'] = df['type'].fillna('manual')
        df['complexity_score'] = df['complexity'].map({'easy': 1, 'medium': 2, 'hard': 3, 'very_hard': 4})
        
        return df
    
    def create_features(self, df: pd.DataFrame) -> np.ndarray:
        """Create feature vectors from data."""
        features = []
        
        for _, row in df.iterrows():
            feature_vector = [
                len(row['text']),
                row.get('complexity_score', 2),
                row.get('estimated_duration', 30),
                row['text'].count(' ') + 1,
                len(row['text'].split())
            ]
            features.append(feature_vector)
        
        return np.array(features)
    
    def split_dataset(self, df: pd.DataFrame, train_ratio: float = 0.8) -> tuple:
        """Split dataset into train and validation."""
        shuffled = df.sample(frac=1).reset_index(drop=True)
        split_idx = int(len(shuffled) * train_ratio)
        
        train = shuffled[:split_idx]
        val = shuffled[split_idx:]
        
        return train, val
    
    def augment_data(self, df: pd.DataFrame, augmentation_factor: int = 2) -> pd.DataFrame:
        """Augment dataset with variations."""
        augmented = [df]
        
        for _ in range(augmentation_factor):
            augmented_df = df.copy()
            augmented_df['text'] = augmented_df['text'].apply(self._paraphrase)
            augmented.append(augmented_df)
        
        return pd.concat(augmented, ignore_index=True)
    
    def _paraphrase(self, text: str) -> str:
        """Simple paraphrasing (can be enhanced with LLM)."""
        return text


_data_processor = None

def get_data_processor() -> DataProcessor:
    """Get singleton data processor."""
    global _data_processor
    if _data_processor is None:
        _data_processor = DataProcessor()
    return _data_processor

