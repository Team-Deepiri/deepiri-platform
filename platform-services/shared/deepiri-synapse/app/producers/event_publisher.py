"""
Event publisher for Synapse
Provides high-level interface for publishing events
"""
import redis.asyncio as redis
from typing import Dict, Any
from datetime import datetime


class EventPublisher:
    """High-level event publisher"""
    
    def __init__(self, redis_client: redis.Redis):
        """Initialize event publisher"""
        self.redis = redis_client
    
    async def publish_model_event(
        self,
        event_type: str,
        model_name: str,
        version: str,
        **kwargs
    ):
        """Publish model-related event"""
        event = {
            "event": event_type,
            "model_name": model_name,
            "version": version,
            "timestamp": datetime.utcnow().isoformat(),
            **kwargs
        }
        return await self.redis.xadd("model-events", event, maxlen=10000, approximate=True)
    
    async def publish_inference_event(
        self,
        model_name: str,
        version: str,
        latency_ms: float,
        **kwargs
    ):
        """Publish inference event"""
        event = {
            "event": "inference-complete",
            "model_name": model_name,
            "version": version,
            "latency_ms": latency_ms,
            "timestamp": datetime.utcnow().isoformat(),
            **kwargs
        }
        return await self.redis.xadd("inference-events", event, maxlen=10000, approximate=True)
    
    async def publish_platform_event(
        self,
        service: str,
        action: str,
        data: Dict[str, Any]
    ):
        """Publish platform event"""
        event = {
            "event": "platform-event",
            "service": service,
            "action": action,
            "data": str(data),  # JSON serialization handled by caller
            "timestamp": datetime.utcnow().isoformat()
        }
        return await self.redis.xadd("platform-events", event, maxlen=10000, approximate=True)

