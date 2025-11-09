"""
Model Evaluation Script
Comprehensive model evaluation with metrics
"""
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset
from peft import PeftModel
import json
import argparse
from pathlib import Path
from typing import Dict
import numpy as np
from sklearn.metrics import accuracy_score, precision_recall_fscore_support
from ..logging_config import get_logger

logger = get_logger("eval.model")


class ModelEvaluator:
    """Comprehensive model evaluation."""
    
    def __init__(self, model_path: str, base_model: Optional[str] = None):
        self.model_path = model_path
        self.base_model = base_model
        self.model = None
        self.tokenizer = None
        self._load_model()
    
    def _load_model(self):
        """Load model for evaluation."""
        logger.info("Loading model for evaluation", path=self.model_path)
        
        if self.base_model:
            base = AutoModelForCausalLM.from_pretrained(self.base_model)
            self.model = PeftModel.from_pretrained(base, self.model_path)
        else:
            self.model = AutoModelForCausalLM.from_pretrained(self.model_path)
        
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_path)
        self.model.eval()
    
    def evaluate_classification(self, test_dataset: str) -> Dict:
        """Evaluate classification task."""
        dataset = load_dataset('json', data_files=test_dataset, split='train')
        
        correct = 0
        total = 0
        predictions = []
        labels = []
        
        for example in dataset:
            text = example['text']
            label = example['label']
            
            inputs = self.tokenizer(text, return_tensors="pt", truncation=True)
            outputs = self.model.generate(**inputs, max_length=50)
            prediction = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            predictions.append(prediction)
            labels.append(label)
            total += 1
        
        accuracy = accuracy_score(labels, predictions)
        precision, recall, f1, _ = precision_recall_fscore_support(
            labels, predictions, average='weighted'
        )
        
        return {
            'accuracy': float(accuracy),
            'precision': float(precision),
            'recall': float(recall),
            'f1': float(f1),
            'total_samples': total
        }
    
    def evaluate_generation(self, test_dataset: str) -> Dict:
        """Evaluate text generation quality."""
        dataset = load_dataset('json', data_files=test_dataset, split='train')
        
        perplexities = []
        bleu_scores = []
        
        for example in dataset:
            prompt = example['prompt']
            reference = example['reference']
            
            inputs = self.tokenizer(prompt, return_tensors="pt")
            outputs = self.model(**inputs, labels=inputs['input_ids'])
            loss = outputs.loss
            perplexity = torch.exp(loss).item()
            perplexities.append(perplexity)
        
        return {
            'avg_perplexity': float(np.mean(perplexities)),
            'samples': len(perplexities)
        }
    
    def benchmark_inference(self, num_samples: int = 100) -> Dict:
        """Benchmark inference speed."""
        import time
        
        test_prompts = ["Test prompt"] * num_samples
        times = []
        
        for prompt in test_prompts:
            inputs = self.tokenizer(prompt, return_tensors="pt")
            start = time.time()
            with torch.no_grad():
                outputs = self.model.generate(**inputs, max_length=50)
            times.append(time.time() - start)
        
        return {
            'avg_latency_ms': float(np.mean(times) * 1000),
            'p50_latency_ms': float(np.percentile(times, 50) * 1000),
            'p95_latency_ms': float(np.percentile(times, 95) * 1000),
            'p99_latency_ms': float(np.percentile(times, 99) * 1000),
            'throughput_per_sec': float(1.0 / np.mean(times))
        }


def main():
    parser = argparse.ArgumentParser(description="Evaluate Model")
    parser.add_argument("--model_path", type=str, required=True)
    parser.add_argument("--base_model", type=str, default=None)
    parser.add_argument("--test_dataset", type=str, required=True)
    parser.add_argument("--task_type", type=str, choices=['classification', 'generation'], default='classification')
    parser.add_argument("--output", type=str, default="evaluation_results.json")
    
    args = parser.parse_args()
    
    evaluator = ModelEvaluator(args.model_path, args.base_model)
    
    if args.task_type == 'classification':
        results = evaluator.evaluate_classification(args.test_dataset)
    else:
        results = evaluator.evaluate_generation(args.test_dataset)
    
    benchmark = evaluator.benchmark_inference()
    results['benchmark'] = benchmark
    
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)
    
    logger.info("Evaluation complete", results=results)


if __name__ == "__main__":
    main()

