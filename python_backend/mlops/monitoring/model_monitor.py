"""
Model Performance Monitoring
MLOps Engineer 2: Monitor deployed models in production
"""
import time
import json
from typing import Dict, List
from datetime import datetime
from pathlib import Path

class ModelMonitor:
    """Monitor model performance and health."""
    
    def __init__(self, model_name: str):
        self.model_name = model_name
        self.metrics = {
            'inference_latency': [],
            'accuracy': [],
            'error_rate': [],
            'throughput': [],
            'resource_usage': []
        }
        self.alerts = []
    
    def log_inference(self, latency: float, success: bool, error: str = None):
        """Log inference metrics."""
        self.metrics['inference_latency'].append({
            'timestamp': datetime.now().isoformat(),
            'latency_ms': latency * 1000,
            'success': success
        })
        
        if not success:
            self.metrics['error_rate'].append({
                'timestamp': datetime.now().isoformat(),
                'error': error
            })
            self._check_alerts('error_rate')
    
    def log_accuracy(self, accuracy: float, dataset: str):
        """Log model accuracy."""
        self.metrics['accuracy'].append({
            'timestamp': datetime.now().isoformat(),
            'accuracy': accuracy,
            'dataset': dataset
        })
        
        if accuracy < 0.7:
            self._check_alerts('accuracy', accuracy)
    
    def log_throughput(self, requests_per_second: float):
        """Log model throughput."""
        self.metrics['throughput'].append({
            'timestamp': datetime.now().isoformat(),
            'rps': requests_per_second
        })
    
    def log_resource_usage(self, cpu: float, memory: float, gpu: float = None):
        """Log resource usage."""
        self.metrics['resource_usage'].append({
            'timestamp': datetime.now().isoformat(),
            'cpu_percent': cpu,
            'memory_mb': memory,
            'gpu_percent': gpu
        })
        
        if cpu > 90 or memory > 90:
            self._check_alerts('resource_usage', {'cpu': cpu, 'memory': memory})
    
    def _check_alerts(self, metric_type: str, value: any = None):
        """Check if alerts should be triggered."""
        alert = {
            'timestamp': datetime.now().isoformat(),
            'model': self.model_name,
            'metric': metric_type,
            'value': value,
            'severity': 'warning'
        }
        
        self.alerts.append(alert)
        print(f"ALERT: {metric_type} - {value}")
    
    def get_summary(self) -> Dict:
        """Get monitoring summary."""
        latencies = [m['latency_ms'] for m in self.metrics['inference_latency']]
        accuracies = [m['accuracy'] for m in self.metrics['accuracy']]
        
        return {
            'model': self.model_name,
            'avg_latency_ms': sum(latencies) / len(latencies) if latencies else 0,
            'avg_accuracy': sum(accuracies) / len(accuracies) if accuracies else 0,
            'error_count': len(self.metrics['error_rate']),
            'alert_count': len(self.alerts),
            'last_updated': datetime.now().isoformat()
        }
    
    def save_metrics(self, path: str):
        """Save metrics to file."""
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'w') as f:
            json.dump({
                'model': self.model_name,
                'metrics': self.metrics,
                'alerts': self.alerts,
                'summary': self.get_summary()
            }, f, indent=2)
        
        print(f"Metrics saved to {path}")


def monitor_models():
    """Main monitoring function."""
    print("=" * 60)
    print("Model Performance Monitoring")
    print("=" * 60)
    
    print("\nMonitored metrics:")
    print("- Inference latency")
    print("- Model accuracy")
    print("- Error rate")
    print("- Throughput (requests/second)")
    print("- Resource usage (CPU, memory, GPU)")
    
    print("\nAlerting:")
    print("- High latency (>500ms)")
    print("- Low accuracy (<70%)")
    print("- High error rate (>5%)")
    print("- Resource exhaustion (>90%)")
    
    print("\nIntegration:")
    print("- Prometheus for metrics collection")
    print("- Grafana for visualization")
    print("- PagerDuty/Slack for alerts")
    
    print("\nNext steps:")
    print("- MLOps Engineer 2: Implement full monitoring system")
    print("- Set up Prometheus exporters")
    print("- Configure alerting rules")
    print("- Create monitoring dashboards")


if __name__ == "__main__":
    monitor_models()

