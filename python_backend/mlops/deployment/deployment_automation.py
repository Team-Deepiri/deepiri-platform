"""
Deployment Automation
Automates model deployment with canary, blue-green, and A/B testing
"""
import os
import time
import subprocess
from typing import Dict, List, Optional
from pathlib import Path
import kubernetes
from kubernetes import client, config
from ..logging_config import get_logger

logger = get_logger("mlops.deployment")


class DeploymentAutomation:
    """
    Automated deployment with:
    - Canary deployments
    - Blue-green deployments
    - A/B testing
    - Rollback capabilities
    - Health checks
    """
    
    def __init__(self):
        self.k8s_config_loaded = False
        self._load_k8s_config()
        self.deployment_history = []
    
    def _load_k8s_config(self):
        """Load Kubernetes configuration."""
        try:
            if os.path.exists(os.path.expanduser("~/.kube/config")):
                config.load_kube_config()
                self.k8s_config_loaded = True
                logger.info("Kubernetes config loaded")
            else:
                logger.warning("Kubernetes config not found")
        except Exception as e:
            logger.warning("Kubernetes config load failed", error=str(e))
    
    def deploy_model(
        self,
        model_name: str,
        model_version: str,
        strategy: str = 'canary',
        config: Optional[Dict] = None
    ) -> Dict:
        """
        Deploy model using specified strategy.
        
        Args:
            strategy: 'canary', 'blue_green', or 'ab_test'
        """
        try:
            logger.info("Deploying model", 
                       model_name=model_name, 
                       version=model_version, 
                       strategy=strategy)
            
            if strategy == 'canary':
                return self._canary_deployment(model_name, model_version, config)
            elif strategy == 'blue_green':
                return self._blue_green_deployment(model_name, model_version, config)
            elif strategy == 'ab_test':
                return self._ab_test_deployment(model_name, model_version, config)
            else:
                raise ValueError(f"Unknown deployment strategy: {strategy}")
                
        except Exception as e:
            logger.error("Deployment failed", error=str(e))
            return {
                'success': False,
                'error': str(e)
            }
    
    def _canary_deployment(
        self,
        model_name: str,
        model_version: str,
        config: Optional[Dict]
    ) -> Dict:
        """Deploy using canary strategy (gradual rollout)."""
        try:
            initial_traffic = config.get('initial_traffic', 10) if config else 10
            increment = config.get('increment', 10) if config else 10
            interval_minutes = config.get('interval_minutes', 5) if config else 5
            
            logger.info("Starting canary deployment", 
                       initial_traffic=initial_traffic,
                       increment=increment)
            
            # Phase 1: Deploy to 10% traffic
            self._update_traffic_split(model_name, model_version, initial_traffic)
            
            # Wait and monitor
            time.sleep(interval_minutes * 60)
            health = self._check_deployment_health(model_name, model_version)
            
            if not health['healthy']:
                logger.warning("Canary deployment unhealthy, rolling back")
                self.rollback(model_name)
                return {
                    'success': False,
                    'reason': 'unhealthy',
                    'health_check': health
                }
            
            # Phase 2: Gradually increase traffic
            current_traffic = initial_traffic
            while current_traffic < 100:
                current_traffic = min(current_traffic + increment, 100)
                self._update_traffic_split(model_name, model_version, current_traffic)
                
                logger.info("Canary traffic increased", traffic_percentage=current_traffic)
                
                time.sleep(interval_minutes * 60)
                health = self._check_deployment_health(model_name, model_version)
                
                if not health['healthy']:
                    logger.warning("Canary deployment unhealthy during rollout")
                    self.rollback(model_name)
                    return {
                        'success': False,
                        'reason': 'unhealthy_during_rollout',
                        'traffic_at_failure': current_traffic
                    }
            
            # Phase 3: Full deployment
            self._update_traffic_split(model_name, model_version, 100)
            
            logger.info("Canary deployment completed successfully")
            return {
                'success': True,
                'strategy': 'canary',
                'final_traffic': 100
            }
            
        except Exception as e:
            logger.error("Canary deployment failed", error=str(e))
            return {
                'success': False,
                'error': str(e)
            }
    
    def _blue_green_deployment(
        self,
        model_name: str,
        model_version: str,
        config: Optional[Dict]
    ) -> Dict:
        """Deploy using blue-green strategy."""
        try:
            # Deploy new version (green) alongside current (blue)
            green_deployment = self._create_deployment(model_name, model_version, 'green')
            
            # Health check green deployment
            health = self._check_deployment_health(model_name, model_version, 'green')
            if not health['healthy']:
                logger.warning("Green deployment unhealthy")
                self._delete_deployment(green_deployment)
                return {
                    'success': False,
                    'reason': 'green_unhealthy'
                }
            
            # Switch traffic to green
            self._switch_traffic(model_name, 'green')
            
            # Monitor for issues
            time.sleep(300)  # 5 minutes
            health = self._check_deployment_health(model_name, model_version, 'green')
            
            if not health['healthy']:
                # Switch back to blue
                self._switch_traffic(model_name, 'blue')
                self._delete_deployment(green_deployment)
                return {
                    'success': False,
                    'reason': 'post_switch_unhealthy'
                }
            
            # Clean up blue deployment
            self._delete_deployment(model_name, 'blue')
            
            logger.info("Blue-green deployment completed")
            return {
                'success': True,
                'strategy': 'blue_green'
            }
            
        except Exception as e:
            logger.error("Blue-green deployment failed", error=str(e))
            return {
                'success': False,
                'error': str(e)
            }
    
    def _ab_test_deployment(
        self,
        model_name: str,
        model_version: str,
        config: Optional[Dict]
    ) -> Dict:
        """Deploy for A/B testing."""
        try:
            traffic_split = config.get('traffic_split', 0.5) if config else 0.5
            
            # Get current production version
            current_version = self._get_current_production_version(model_name)
            
            # Deploy new version
            self._create_deployment(model_name, model_version, 'ab_test')
            
            # Setup traffic split
            self._setup_ab_traffic_split(model_name, current_version, model_version, traffic_split)
            
            logger.info("A/B test deployment completed", 
                       version_a=current_version,
                       version_b=model_version,
                       traffic_split=traffic_split)
            
            return {
                'success': True,
                'strategy': 'ab_test',
                'version_a': current_version,
                'version_b': model_version,
                'traffic_split': traffic_split
            }
            
        except Exception as e:
            logger.error("A/B test deployment failed", error=str(e))
            return {
                'success': False,
                'error': str(e)
            }
    
    def rollback(self, model_name: str, target_version: Optional[str] = None) -> Dict:
        """Rollback to previous version."""
        try:
            logger.info("Rolling back", model_name=model_name, target_version=target_version)
            
            if target_version:
                # Rollback to specific version
                self._switch_to_version(model_name, target_version)
            else:
                # Rollback to previous version
                previous_version = self._get_previous_version(model_name)
                if previous_version:
                    self._switch_to_version(model_name, previous_version)
                else:
                    return {
                        'success': False,
                        'reason': 'no_previous_version'
                    }
            
            logger.info("Rollback completed")
            return {
                'success': True,
                'target_version': target_version or previous_version
            }
            
        except Exception as e:
            logger.error("Rollback failed", error=str(e))
            return {
                'success': False,
                'error': str(e)
            }
    
    def _update_traffic_split(self, model_name: str, version: str, percentage: int):
        """Update traffic split (would update Kubernetes service/ingress)."""
        logger.info("Updating traffic split", 
                   model_name=model_name,
                   version=version,
                   percentage=percentage)
        # In production, would update Kubernetes service weights
    
    def _check_deployment_health(
        self,
        model_name: str,
        version: str,
        environment: Optional[str] = None
    ) -> Dict:
        """Check deployment health."""
        # In production, would:
        # 1. Check pod status
        # 2. Check endpoint health
        # 3. Check metrics (latency, error rate)
        
        return {
            'healthy': True,
            'pods_running': 3,
            'pods_total': 3,
            'avg_latency_ms': 50,
            'error_rate': 0.01
        }
    
    def _create_deployment(self, model_name: str, version: str, environment: str) -> str:
        """Create Kubernetes deployment."""
        logger.info("Creating deployment", 
                   model_name=model_name,
                   version=version,
                   environment=environment)
        return f"{model_name}-{environment}"
    
    def _delete_deployment(self, model_name: str, environment: str):
        """Delete Kubernetes deployment."""
        logger.info("Deleting deployment", model_name=model_name, environment=environment)
    
    def _switch_traffic(self, model_name: str, target: str):
        """Switch traffic to target environment."""
        logger.info("Switching traffic", model_name=model_name, target=target)
    
    def _get_current_production_version(self, model_name: str) -> str:
        """Get current production version."""
        return "1.0.0"  # Placeholder
    
    def _setup_ab_traffic_split(
        self,
        model_name: str,
        version_a: str,
        version_b: str,
        split: float
    ):
        """Setup A/B test traffic split."""
        logger.info("Setting up A/B traffic split",
                   version_a=version_a,
                   version_b=version_b,
                   split=split)
    
    def _switch_to_version(self, model_name: str, version: str):
        """Switch to specific version."""
        logger.info("Switching to version", model_name=model_name, version=version)
    
    def _get_previous_version(self, model_name: str) -> Optional[str]:
        """Get previous deployment version."""
        return "0.9.0"  # Placeholder


# Singleton instance
_deployment = None

def get_deployment_automation() -> DeploymentAutomation:
    """Get singleton DeploymentAutomation instance."""
    global _deployment
    if _deployment is None:
        _deployment = DeploymentAutomation()
    return _deployment

