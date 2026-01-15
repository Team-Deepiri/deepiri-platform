"""
Event publisher for Synapse
Provides high-level interface for publishing events
"""
import redis.asyncio as redis
from typing import Dict, Any, Optional
from datetime import datetime
from ..middleware.validation import ValidationMiddleware


class EventPublisher:
    """High-level event publisher"""
    
    def __init__(
        self,
        redis_client: redis.Redis,
        validation_middleware: Optional[ValidationMiddleware] = None
    ):
        """
        Initialize event publisher
        
        Args:
            redis_client: Redis client
            validation_middleware: Optional validation middleware for event validation
        """
        self.redis = redis_client
        self.validation_middleware = validation_middleware
    
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
        
        # Use validation middleware if available
        if self.validation_middleware:
            success, message_id, error = await self.validation_middleware.validate_and_publish(
                "model-events",
                event
            )
            if not success:
                raise ValueError(f"Failed to publish model event: {error}")
            return message_id
        
        # Fallback to direct Redis publish
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
        
        # Use validation middleware if available
        if self.validation_middleware:
            success, message_id, error = await self.validation_middleware.validate_and_publish(
                "inference-events",
                event
            )
            if not success:
                raise ValueError(f"Failed to publish inference event: {error}")
            return message_id
        
        # Fallback to direct Redis publish
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
        
        # Use validation middleware if available
        if self.validation_middleware:
            success, message_id, error = await self.validation_middleware.validate_and_publish(
                "platform-events",
                event
            )
            if not success:
                raise ValueError(f"Failed to publish platform event: {error}")
            return message_id
        
        # Fallback to direct Redis publish
        return await self.redis.xadd("platform-events", event, maxlen=10000, approximate=True)

