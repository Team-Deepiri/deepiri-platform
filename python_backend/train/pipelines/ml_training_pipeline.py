"""
Complete ML Training Pipeline
Train models from collected data with local/API model support
"""
import json
import asyncio
from pathlib import Path
from typing import Dict, Optional
from .full_training_pipeline import FullTrainingPipeline
from .data_collection_pipeline import get_data_collector
from .lora_training import QLoRATrainingPipeline
from .bandit_training import train_bandit_from_data
from ..infrastructure.experiment_tracker import ExperimentTracker
from ..logging_config import get_logger

logger = get_logger("train.ml_pipeline")


class MLTrainingPipeline:
    """Complete ML training pipeline from data collection to deployment."""
    
    def __init__(self, config: Dict):
        self.config = config
        self.data_collector = get_data_collector()
        self.tracker = None
    
    def collect_training_data(self, days: int = 7):
        """Collect training data from recent usage."""
        logger.info("Collecting training data", days=days)
        
        classification_path = "train/data/collected_classifications.jsonl"
        challenge_path = "train/data/collected_challenges.jsonl"
        
        self.data_collector.export_for_training(classification_path, "classification")
        self.data_collector.export_for_training(challenge_path, "challenge")
        
        logger.info("Training data collected", 
                   classification_samples=self._count_lines(classification_path),
                   challenge_samples=self._count_lines(challenge_path))
    
    def _count_lines(self, filepath: str) -> int:
        """Count lines in file."""
        try:
            with open(filepath, 'r') as f:
                return sum(1 for _ in f)
        except FileNotFoundError:
            return 0
    
    def prepare_training_data(self):
        """Prepare and validate training data."""
        from ..data.prepare_dataset import DatasetPreparer
        
        preparer = DatasetPreparer()
        
        raw_classification = self._load_raw_data("data/raw/classifications.json")
        raw_challenges = self._load_raw_data("data/raw/challenges.json")
        
        if raw_classification:
            preparer.prepare_task_classification(
                raw_classification,
                "train/data/task_classification.jsonl"
            )
        
        if raw_challenges:
            preparer.prepare_challenge_generation(
                raw_challenges,
                "train/data/challenge_generation.jsonl"
            )
    
    def _load_raw_data(self, path: str) -> Optional[list]:
        """Load raw data file."""
        try:
            with open(path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return None
    
    def train_task_classifier(self):
        """Train task classification model."""
        logger.info("Training task classifier")
        
        config = {
            "experiment_name": "task_classifier_v1",
            "base_model": self.config.get("base_model", "mistralai/Mistral-7B-v0.1"),
            "use_qlora": True,
            "train_dataset_path": "train/data/task_classification.jsonl",
            "output_dir": "train/models/task_classifier",
            **self.config.get("training_config", {})
        }
        
        pipeline = FullTrainingPipeline(config)
        output_dir = pipeline.run()
        
        logger.info("Task classifier training complete", output_dir=output_dir)
        return output_dir
    
    def train_challenge_generator(self):
        """Train challenge generation model."""
        logger.info("Training challenge generator")
        
        config = {
            "experiment_name": "challenge_generator_v1",
            "base_model": self.config.get("base_model", "mistralai/Mistral-7B-v0.1"),
            "use_qlora": True,
            "train_dataset_path": "train/data/challenge_generation.jsonl",
            "output_dir": "train/models/challenge_generator",
            **self.config.get("training_config", {})
        }
        
        pipeline = FullTrainingPipeline(config)
        output_dir = pipeline.run()
        
        logger.info("Challenge generator training complete", output_dir=output_dir)
        return output_dir
    
    def train_bandit(self):
        """Train multi-armed bandit."""
        logger.info("Training bandit model")
        
        dataset_path = "train/data/bandit_training.jsonl"
        output_path = "train/models/bandit/bandit.pkl"
        
        bandit = train_bandit_from_data(dataset_path, output_path)
        
        logger.info("Bandit training complete", output_path=output_path)
        return output_path
    
    def run_full_pipeline(self):
        """Run complete training pipeline."""
        logger.info("Starting full ML training pipeline")
        
        self.collect_training_data()
        self.prepare_training_data()
        
        if self.config.get("train_classifier", True):
            self.train_task_classifier()
        
        if self.config.get("train_generator", True):
            self.train_challenge_generator()
        
        if self.config.get("train_bandit", True):
            self.train_bandit()
        
        logger.info("Full ML training pipeline complete")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="ML Training Pipeline")
    parser.add_argument("--config", type=str, default="train/configs/ml_training_config.json")
    parser.add_argument("--collect-only", action="store_true")
    parser.add_argument("--train-classifier", action="store_true")
    parser.add_argument("--train-generator", action="store_true")
    parser.add_argument("--train-bandit", action="store_true")
    
    args = parser.parse_args()
    
    with open(args.config, 'r') as f:
        config = json.load(f)
    
    pipeline = MLTrainingPipeline(config)
    
    if args.collect_only:
        pipeline.collect_training_data()
    else:
        if args.train_classifier:
            config['train_classifier'] = True
        if args.train_generator:
            config['train_generator'] = True
        if args.train_bandit:
            config['train_bandit'] = True
        
        pipeline.run_full_pipeline()


if __name__ == "__main__":
    main()

