"""
Model Monitoring Service
Monitors model performance, drift, and data quality
"""
import time
import numpy as np
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from collections import deque
import mlflow
from ..logging_config import get_logger

logger = get_logger("mlops.model_monitor")


class ModelMonitor:
    """
    Monitors:
    - Model performance metrics
    - Data drift detection
    - Prediction drift detection
    - Data quality issues
    - Model degradation
    """
    
    def __init__(self):
        self.monitoring_data = {}  # model_name -> monitoring data
        self.alert_thresholds = {
            'accuracy_drop': 0.05,  # 5% drop
            'latency_increase': 0.2,  # 20% increase
            'error_rate': 0.05,  # 5% error rate
            'drift_score': 0.3  # 30% drift
        }
        self.baseline_metrics = {}
    
    def record_prediction(
        self,
        model_name: str,
        prediction: any,
        actual: Optional[any] = None,
        features: Optional[Dict] = None,
        latency_ms: Optional[float] = None
    ):
        """Record model prediction for monitoring."""
        if model_name not in self.monitoring_data:
            self.monitoring_data[model_name] = {
                'predictions': deque(maxlen=10000),
                'latencies': deque(maxlen=1000),
                'errors': deque(maxlen=1000),
                'feature_distributions': {}
            }
        
        data = self.monitoring_data[model_name]
        
        # Record prediction
        data['predictions'].append({
            'prediction': prediction,
            'actual': actual,
            'timestamp': datetime.utcnow(),
            'features': features
        })
        
        # Record latency
        if latency_ms is not None:
            data['latencies'].append({
                'latency_ms': latency_ms,
                'timestamp': datetime.utcnow()
            })
        
        # Check for issues
        self._check_for_issues(model_name)
    
    def record_error(self, model_name: str, error: Exception, context: Optional[Dict] = None):
        """Record model error."""
        if model_name not in self.monitoring_data:
            self.monitoring_data[model_name] = {
                'predictions': deque(maxlen=10000),
                'latencies': deque(maxlen=1000),
                'errors': deque(maxlen=1000),
                'feature_distributions': {}
            }
        
        self.monitoring_data[model_name]['errors'].append({
            'error': str(error),
            'context': context or {},
            'timestamp': datetime.utcnow()
        })
        
        self._check_error_rate(model_name)
    
    def detect_data_drift(
        self,
        model_name: str,
        current_features: Dict,
        reference_features: Optional[Dict] = None
    ) -> Dict:
        """
        Detect data drift in input features.
        
        Returns:
            Drift detection results
        """
        try:
            if model_name not in self.monitoring_data:
                return {'drift_detected': False, 'reason': 'no_monitoring_data'}
            
            # Get reference distribution (baseline or recent)
            if reference_features is None:
                reference_features = self.baseline_metrics.get(model_name, {})
            
            if not reference_features:
                # Use recent predictions as baseline
                recent_predictions = list(self.monitoring_data[model_name]['predictions'])[-1000:]
                if recent_predictions:
                    reference_features = self._calculate_feature_distribution(recent_predictions)
                else:
                    return {'drift_detected': False, 'reason': 'insufficient_data'}
            
            # Calculate drift score
            drift_score = self._calculate_drift_score(current_features, reference_features)
            
            drift_detected = drift_score > self.alert_thresholds['drift_score']
            
            if drift_detected:
                logger.warning("Data drift detected", 
                             model_name=model_name, 
                             drift_score=drift_score)
            
            return {
                'drift_detected': drift_detected,
                'drift_score': drift_score,
                'threshold': self.alert_thresholds['drift_score'],
                'features_compared': list(current_features.keys())
            }
            
        except Exception as e:
            logger.error("Error detecting data drift", error=str(e))
            return {'drift_detected': False, 'error': str(e)}
    
    def detect_prediction_drift(self, model_name: str) -> Dict:
        """Detect drift in prediction distribution."""
        try:
            if model_name not in self.monitoring_data:
                return {'drift_detected': False}
            
            predictions = list(self.monitoring_data[model_name]['predictions'])
            if len(predictions) < 100:
                return {'drift_detected': False, 'reason': 'insufficient_data'}
            
            # Compare recent vs older predictions
            recent = predictions[-500:]
            older = predictions[-1000:-500] if len(predictions) >= 1000 else predictions[:500]
            
            recent_dist = self._calculate_prediction_distribution(recent)
            older_dist = self._calculate_prediction_distribution(older)
            
            drift_score = self._kl_divergence(recent_dist, older_dist)
            drift_detected = drift_score > self.alert_thresholds['drift_score']
            
            return {
                'drift_detected': drift_detected,
                'drift_score': drift_score,
                'recent_distribution': recent_dist,
                'older_distribution': older_dist
            }
            
        except Exception as e:
            logger.error("Error detecting prediction drift", error=str(e))
            return {'drift_detected': False, 'error': str(e)}
    
    def check_model_performance(self, model_name: str) -> Dict:
        """Check current model performance metrics."""
        try:
            if model_name not in self.monitoring_data:
                return {'status': 'no_data'}
            
            data = self.monitoring_data[model_name]
            predictions = list(data['predictions'])
            
            if len(predictions) < 10:
                return {'status': 'insufficient_data'}
            
            # Calculate accuracy if actuals available
            accuracy = None
            if all(p.get('actual') is not None for p in predictions[-100:]):
                correct = sum(1 for p in predictions[-100:] if p['prediction'] == p['actual'])
                accuracy = correct / len(predictions[-100:])
            
            # Calculate latency
            latencies = list(data['latencies'])
            avg_latency = np.mean([l['latency_ms'] for l in latencies[-100:]]) if latencies else None
            
            # Error rate
            errors = list(data['errors'])
            error_rate = len(errors) / max(len(predictions), 1)
            
            # Compare to baseline
            baseline = self.baseline_metrics.get(model_name, {})
            performance_status = 'healthy'
            
            if baseline:
                if accuracy and baseline.get('accuracy'):
                    if accuracy < baseline['accuracy'] - self.alert_thresholds['accuracy_drop']:
                        performance_status = 'degraded'
                
                if avg_latency and baseline.get('avg_latency'):
                    if avg_latency > baseline['avg_latency'] * (1 + self.alert_thresholds['latency_increase']):
                        performance_status = 'degraded'
            
            return {
                'status': performance_status,
                'accuracy': accuracy,
                'avg_latency_ms': avg_latency,
                'error_rate': error_rate,
                'total_predictions': len(predictions),
                'baseline': baseline
            }
            
        except Exception as e:
            logger.error("Error checking model performance", error=str(e))
            return {'status': 'error', 'error': str(e)}
    
    def set_baseline(self, model_name: str, metrics: Dict):
        """Set baseline metrics for comparison."""
        self.baseline_metrics[model_name] = metrics
        logger.info("Baseline set", model_name=model_name, metrics=metrics)
    
    def _check_for_issues(self, model_name: str):
        """Check for monitoring issues and alert if needed."""
        # Check performance
        performance = self.check_model_performance(model_name)
        if performance.get('status') == 'degraded':
            self._alert('performance_degradation', model_name, performance)
        
        # Check error rate
        self._check_error_rate(model_name)
    
    def _check_error_rate(self, model_name: str):
        """Check error rate and alert if high."""
        if model_name not in self.monitoring_data:
            return
        
        errors = list(self.monitoring_data[model_name]['errors'])
        predictions = list(self.monitoring_data[model_name]['predictions'])
        
        if len(predictions) < 10:
            return
        
        error_rate = len(errors) / len(predictions)
        if error_rate > self.alert_thresholds['error_rate']:
            self._alert('high_error_rate', model_name, {'error_rate': error_rate})
    
    def _alert(self, alert_type: str, model_name: str, data: Dict):
        """Send alert (would integrate with alerting system)."""
        logger.warning("Alert triggered", 
                      alert_type=alert_type, 
                      model_name=model_name, 
                      data=data)
        # In production, would send to PagerDuty, Slack, etc.
    
    def _calculate_feature_distribution(self, predictions: List[Dict]) -> Dict:
        """Calculate feature distribution from predictions."""
        # Simplified - would calculate actual distributions
        return {}
    
    def _calculate_drift_score(self, current: Dict, reference: Dict) -> float:
        """Calculate drift score between distributions."""
        # Simplified KL divergence or statistical test
        return 0.1  # Placeholder
    
    def _calculate_prediction_distribution(self, predictions: List[Dict]) -> Dict:
        """Calculate prediction distribution."""
        pred_values = [p['prediction'] for p in predictions if 'prediction' in p]
        unique, counts = np.unique(pred_values, return_counts=True)
        return dict(zip(unique, counts / len(pred_values)))
    
    def _kl_divergence(self, p: Dict, q: Dict) -> float:
        """Calculate KL divergence between distributions."""
        # Simplified KL divergence
        all_keys = set(p.keys()) | set(q.keys())
        kl = 0.0
        for key in all_keys:
            p_val = p.get(key, 1e-10)
            q_val = q.get(key, 1e-10)
            kl += p_val * np.log(p_val / q_val)
        return kl


# Singleton instance
_model_monitor = None

def get_model_monitor() -> ModelMonitor:
    """Get singleton ModelMonitor instance."""
    global _model_monitor
    if _model_monitor is None:
        _model_monitor = ModelMonitor()
    return _model_monitor
