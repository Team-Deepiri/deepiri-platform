"""
Validation Middleware
Intercepts events and validates them before publishing
"""
import redis.asyncio as redis
from typing import Dict, Any, Optional, Tuple
from datetime import datetime
import logging
from ..schemas.validators import validate_event
from ..schemas.registry import SchemaRegistry
from ..streams.dead_letter_queue import DeadLetterQueue

logger = logging.getLogger(__name__)


class ValidationMiddleware:
    """Middleware that validates events before publishing"""
    
    def __init__(
        self,
        redis_client: redis.Redis,
        schema_registry: Optional[SchemaRegistry] = None,
        dead_letter_queue: Optional[DeadLetterQueue] = None,
        enable_validation: bool = True,
        enable_schema_registry: bool = True
    ):
        """
        Initialize validation middleware
        
        Args:
            redis_client: Redis client
            schema_registry: Schema registry instance (optional)
            dead_letter_queue: Dead letter queue instance (optional)
            enable_validation: Enable event validation
            enable_schema_registry: Enable schema registry checks
        """
        self.redis = redis_client
        self.schema_registry = schema_registry
        self.dead_letter_queue = dead_letter_queue or DeadLetterQueue(redis_client)
        self.enable_validation = enable_validation
        self.enable_schema_registry = enable_schema_registry
        
        # Statistics
        self.stats = {
            "validated": 0,
            "invalid": 0,
            "sent_to_dlq": 0
        }
    
    async def validate_and_publish(
        self,
        stream_name: str,
        event_data: Dict[str, Any],
        maxlen: int = 10000
    ) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Validate event and publish to stream
        
        Args:
            stream_name: Stream name
            event_data: Event data to validate and publish
            maxlen: Maximum stream length
        
        Returns:
            Tuple of (success, message_id, error_message)
        """
        try:
            # Step 1: Schema registry check (if enabled)
            if self.enable_schema_registry and self.schema_registry:
                event_type = event_data.get("event")
                if event_type:
                    latest_version = await self.schema_registry.get_latest_version(
                        stream_name,
                        event_type
                    )
                    if latest_version:
                        # Add schema version to event metadata
                        if "metadata" not in event_data:
                            event_data["metadata"] = {}
                        event_data["metadata"]["schema_version"] = latest_version
            
            # Step 2: Validate event schema
            if self.enable_validation:
                try:
                    validated_data = validate_event(stream_name, event_data)
                    event_data = validated_data
                    self.stats["validated"] += 1
                except ValueError as e:
                    # Validation failed - send to dead letter queue
                    error_msg = f"Validation failed: {str(e)}"
                    logger.warning(f"Event validation failed for {stream_name}: {error_msg}")
                    
                    await self._handle_invalid_event(
                        stream_name,
                        event_data,
                        error_msg
                    )
                    
                    self.stats["invalid"] += 1
                    return False, None, error_msg
            
            # Step 3: Add validation metadata
            if "metadata" not in event_data:
                event_data["metadata"] = {}
            event_data["metadata"]["validated_at"] = datetime.utcnow().isoformat()
            event_data["metadata"]["validated"] = True
            
            # Step 4: Publish to stream
            message_id = await self.redis.xadd(
                stream_name,
                event_data,
                maxlen=maxlen,
                approximate=True
            )
            
            logger.debug(f"Published event to {stream_name}: {message_id}")
            return True, message_id, None
            
        except Exception as e:
            error_msg = f"Unexpected error during validation/publish: {str(e)}"
            logger.error(error_msg, exc_info=True)
            
            # Send to dead letter queue
            await self._handle_invalid_event(
                stream_name,
                event_data,
                error_msg
            )
            
            return False, None, error_msg
    
    async def _handle_invalid_event(
        self,
        stream_name: str,
        event_data: Dict[str, Any],
        error_message: str
    ):
        """Handle invalid event by sending to dead letter queue"""
        try:
            await self.dead_letter_queue.add_failed_event(
                stream_name=stream_name,
                event_data=event_data,
                error_message=error_message,
                failure_type="validation_error"
            )
            self.stats["sent_to_dlq"] += 1
            logger.info(f"Sent invalid event to dead letter queue: {stream_name}")
        except Exception as e:
            logger.error(f"Failed to send event to dead letter queue: {e}", exc_info=True)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get validation statistics"""
        total = self.stats["validated"] + self.stats["invalid"]
        success_rate = (
            (self.stats["validated"] / total * 100)
            if total > 0 else 100.0
        )
        
        return {
            **self.stats,
            "total_processed": total,
            "success_rate_percent": round(success_rate, 2)
        }
    
    def reset_stats(self):
        """Reset statistics"""
        self.stats = {
            "validated": 0,
            "invalid": 0,
            "sent_to_dlq": 0
        }

