"""
Dataset Preparation Script
Prepare and validate training datasets
"""
import json
from pathlib import Path
from typing import List, Dict
import hashlib
from ..logging_config import get_logger

logger = get_logger("data.prepare")


class DatasetPreparer:
    """Prepare datasets for training."""
    
    @staticmethod
    def prepare_task_classification(raw_data: List[Dict], output_path: str):
        """Prepare task classification dataset."""
        logger.info("Preparing task classification dataset", samples=len(raw_data))
        
        prepared = []
        for item in raw_data:
            prepared.append({
                "text": item.get('title', '') + " " + item.get('description', ''),
                "label": item.get('type', 'manual'),
                "metadata": {
                    "complexity": item.get('complexity', 'medium'),
                    "duration": item.get('estimated_duration', 30)
                }
            })
        
        with open(output_path, 'w') as f:
            for item in prepared:
                f.write(json.dumps(item) + '\n')
        
        logger.info("Dataset prepared", output_path=output_path, samples=len(prepared))
        return output_path
    
    @staticmethod
    def prepare_challenge_generation(raw_data: List[Dict], output_path: str):
        """Prepare challenge generation dataset."""
        logger.info("Preparing challenge generation dataset", samples=len(raw_data))
        
        prepared = []
        for item in raw_data:
            task_text = f"Task: {item.get('task_title', '')}\nDescription: {item.get('task_description', '')}"
            challenge_text = f"Challenge: {item.get('challenge_title', '')}\n{item.get('challenge_description', '')}"
            
            prepared.append({
                "input": task_text,
                "output": challenge_text,
                "metadata": {
                    "challenge_type": item.get('challenge_type', 'timed_completion'),
                    "difficulty": item.get('difficulty', 'medium'),
                    "points": item.get('points_reward', 100)
                }
            })
        
        with open(output_path, 'w') as f:
            for item in prepared:
                f.write(json.dumps(item) + '\n')
        
        logger.info("Dataset prepared", output_path=output_path, samples=len(prepared))
        return output_path
    
    @staticmethod
    def validate_dataset(dataset_path: str) -> Dict:
        """Validate dataset format and quality."""
        logger.info("Validating dataset", path=dataset_path)
        
        issues = []
        samples = []
        
        with open(dataset_path, 'r') as f:
            for i, line in enumerate(f, 1):
                try:
                    sample = json.loads(line)
                    samples.append(sample)
                except json.JSONDecodeError as e:
                    issues.append(f"Line {i}: JSON decode error - {e}")
        
        stats = {
            "total_samples": len(samples),
            "issues": issues,
            "valid_samples": len(samples) - len(issues)
        }
        
        logger.info("Dataset validation complete", stats=stats)
        return stats
    
    @staticmethod
    def compute_dataset_hash(dataset_path: str) -> str:
        """Compute SHA256 hash of dataset."""
        sha256 = hashlib.sha256()
        with open(dataset_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256.update(chunk)
        return sha256.hexdigest()

