"""
Performance Monitoring Service
Monitor model and system performance
"""
import time
from typing import Dict, List
from collections import deque
from datetime import datetime
from ..logging_config import get_logger

logger = get_logger("service.monitor")


class PerformanceMonitor:
    """Monitor system and model performance."""
    
    def __init__(self, window_size: int = 100):
        self.window_size = window_size
        self.latencies = deque(maxlen=window_size)
        self.errors = deque(maxlen=window_size)
        self.throughput = deque(maxlen=window_size)
        self.metrics = {}
    
    def record_latency(self, endpoint: str, latency_ms: float):
        """Record endpoint latency."""
        self.latencies.append({
            'endpoint': endpoint,
            'latency_ms': latency_ms,
            'timestamp': datetime.now().isoformat()
        })
        
        if endpoint not in self.metrics:
            self.metrics[endpoint] = {'count': 0, 'total_latency': 0.0}
        
        self.metrics[endpoint]['count'] += 1
        self.metrics[endpoint]['total_latency'] += latency_ms
    
    def record_error(self, endpoint: str, error_type: str):
        """Record error."""
        self.errors.append({
            'endpoint': endpoint,
            'error_type': error_type,
            'timestamp': datetime.now().isoformat()
        })
    
    def record_throughput(self, requests_per_second: float):
        """Record throughput."""
        self.throughput.append({
            'rps': requests_per_second,
            'timestamp': datetime.now().isoformat()
        })
    
    def get_stats(self) -> Dict:
        """Get performance statistics."""
        if not self.latencies:
            return {}
        
        latencies_ms = [l['latency_ms'] for l in self.latencies]
        
        stats = {
            'avg_latency_ms': sum(latencies_ms) / len(latencies_ms),
            'p50_latency_ms': sorted(latencies_ms)[len(latencies_ms) // 2],
            'p95_latency_ms': sorted(latencies_ms)[int(len(latencies_ms) * 0.95)],
            'p99_latency_ms': sorted(latencies_ms)[int(len(latencies_ms) * 0.99)],
            'error_count': len(self.errors),
            'error_rate': len(self.errors) / len(self.latencies) if self.latencies else 0.0,
            'endpoint_metrics': self.metrics
        }
        
        if self.throughput:
            avg_rps = sum(t['rps'] for t in self.throughput) / len(self.throughput)
            stats['avg_throughput_rps'] = avg_rps
        
        return stats
    
    def check_alerts(self) -> List[Dict]:
        """Check for performance alerts."""
        alerts = []
        stats = self.get_stats()
        
        if stats.get('avg_latency_ms', 0) > 1000:
            alerts.append({
                'type': 'high_latency',
                'severity': 'warning',
                'message': f"Average latency is {stats['avg_latency_ms']:.2f}ms"
            })
        
        if stats.get('error_rate', 0) > 0.05:
            alerts.append({
                'type': 'high_error_rate',
                'severity': 'critical',
                'message': f"Error rate is {stats['error_rate']*100:.2f}%"
            })
        
        return alerts


_performance_monitor = None

def get_performance_monitor() -> PerformanceMonitor:
    """Get singleton performance monitor."""
    global _performance_monitor
    if _performance_monitor is None:
        _performance_monitor = PerformanceMonitor()
    return _performance_monitor

