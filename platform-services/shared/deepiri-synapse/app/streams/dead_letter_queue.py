"""
Dead Letter Queue (DLQ)
Stores events that failed validation or processing
"""
import redis.asyncio as redis
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
import json
import logging

logger = logging.getLogger(__name__)


class DeadLetterQueue:
    """Dead letter queue for failed events"""
    
    def __init__(self, redis_client: redis.Redis):
        """Initialize dead letter queue"""
        self.redis = redis_client
        self.dlq_stream_prefix = "dlq:"
        self.dlq_metadata_prefix = "dlq:metadata:"
    
    async def add_failed_event(
        self,
        stream_name: str,
        event_data: Dict[str, Any],
        error_message: str,
        failure_type: str = "unknown",
        retry_count: int = 0,
        max_retries: int = 3
    ) -> str:
        """
        Add failed event to dead letter queue
        
        Args:
            stream_name: Original stream name
            event_data: Event data that failed
            error_message: Error message
            failure_type: Type of failure (validation_error, processing_error, etc.)
            retry_count: Number of retry attempts
            max_retries: Maximum retry attempts
        
        Returns:
            Message ID in DLQ
        """
        dlq_stream_name = f"{self.dlq_stream_prefix}{stream_name}"
        
        # Create DLQ event with metadata
        dlq_event = {
            "original_stream": stream_name,
            "event_data": json.dumps(event_data),
            "error_message": error_message,
            "failure_type": failure_type,
            "retry_count": str(retry_count),
            "max_retries": str(max_retries),
            "failed_at": datetime.utcnow().isoformat(),
            "can_retry": "true" if retry_count < max_retries else "false"
        }
        
        # Publish to DLQ stream
        message_id = await self.redis.xadd(
            dlq_stream_name,
            dlq_event,
            maxlen=100000,  # Keep more DLQ events for debugging
            approximate=True
        )
        
        # Store metadata
        await self._update_dlq_metadata(stream_name, failure_type)
        
        logger.info(
            f"Added failed event to DLQ: {stream_name} -> {dlq_stream_name} "
            f"(ID: {message_id}, Type: {failure_type})"
        )
        
        return message_id
    
    async def get_failed_events(
        self,
        stream_name: str,
        count: int = 100,
        failure_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get failed events from dead letter queue
        
        Args:
            stream_name: Original stream name
            count: Number of events to retrieve
            failure_type: Filter by failure type (optional)
        
        Returns:
            List of failed events
        """
        dlq_stream_name = f"{self.dlq_stream_prefix}{stream_name}"
        
        try:
            # Get recent messages
            messages = await self.redis.xrevrange(
                dlq_stream_name,
                count=count
            )
            
            failed_events = []
            for msg_id, data in messages:
                # Filter by failure type if specified
                if failure_type and data.get("failure_type") != failure_type:
                    continue
                
                # Parse event data
                event_data = None
                if "event_data" in data:
                    try:
                        event_data = json.loads(data["event_data"])
                    except json.JSONDecodeError:
                        event_data = data["event_data"]
                
                failed_events.append({
                    "dlq_message_id": msg_id,
                    "original_stream": data.get("original_stream"),
                    "event_data": event_data,
                    "error_message": data.get("error_message"),
                    "failure_type": data.get("failure_type"),
                    "retry_count": int(data.get("retry_count", 0)),
                    "max_retries": int(data.get("max_retries", 3)),
                    "failed_at": data.get("failed_at"),
                    "can_retry": data.get("can_retry") == "true"
                })
            
            return failed_events
            
        except redis.ResponseError:
            # Stream doesn't exist
            return []
    
    async def retry_event(
        self,
        stream_name: str,
        dlq_message_id: str,
        validation_middleware=None
    ) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Retry a failed event
        
        Args:
            stream_name: Original stream name
            dlq_message_id: Message ID in DLQ
            validation_middleware: Validation middleware to use for retry
        
        Returns:
            Tuple of (success, new_message_id, error_message)
        """
        dlq_stream_name = f"{self.dlq_stream_prefix}{stream_name}"
        
        try:
            # Get the failed event
            messages = await self.redis.xrange(
                dlq_stream_name,
                min=dlq_message_id,
                max=dlq_message_id,
                count=1
            )
            
            if not messages:
                return False, None, "Event not found in DLQ"
            
            msg_id, data = messages[0]
            
            # Parse event data
            event_data = json.loads(data["event_data"])
            retry_count = int(data.get("retry_count", 0))
            max_retries = int(data.get("max_retries", 3))
            
            if retry_count >= max_retries:
                return False, None, "Max retries exceeded"
            
            # Retry publishing
            if validation_middleware:
                success, new_msg_id, error = await validation_middleware.validate_and_publish(
                    stream_name,
                    event_data
                )
                
                if success:
                    # Remove from DLQ on success
                    await self.redis.xdel(dlq_stream_name, dlq_message_id)
                    logger.info(f"Successfully retried event {dlq_message_id}")
                    return True, new_msg_id, None
                else:
                    # Increment retry count and update DLQ entry
                    await self.add_failed_event(
                        stream_name=stream_name,
                        event_data=event_data,
                        error_message=error or "Retry failed",
                        failure_type=data.get("failure_type", "unknown"),
                        retry_count=retry_count + 1,
                        max_retries=max_retries
                    )
                    # Remove old DLQ entry
                    await self.redis.xdel(dlq_stream_name, dlq_message_id)
                    return False, None, error
            else:
                return False, None, "Validation middleware not provided"
                
        except Exception as e:
            error_msg = f"Error retrying event: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return False, None, error_msg
    
    async def get_dlq_stats(self, stream_name: Optional[str] = None) -> Dict[str, Any]:
        """
        Get dead letter queue statistics
        
        Args:
            stream_name: Stream name (None for all streams)
        
        Returns:
            DLQ statistics
        """
        if stream_name:
            dlq_stream_name = f"{self.dlq_stream_prefix}{stream_name}"
            try:
                length = await self.redis.xlen(dlq_stream_name)
                return {
                    "stream": stream_name,
                    "dlq_stream": dlq_stream_name,
                    "failed_events_count": length
                }
            except (redis.ResponseError, Exception):
                # Stream doesn't exist or any other error - return 0
                return {
                    "stream": stream_name,
                    "dlq_stream": dlq_stream_name,
                    "failed_events_count": 0
                }
        else:
            # Get stats for all DLQ streams
            pattern = f"{self.dlq_stream_prefix}*"
            keys = await self._scan_keys(pattern)
            
            stats = {}
            total_failed = 0
            
            for key in keys:
                stream_name = key.replace(self.dlq_stream_prefix, "")
                try:
                    length = await self.redis.xlen(key)
                    stats[stream_name] = {
                        "failed_events_count": length
                    }
                    total_failed += length
                except redis.ResponseError:
                    stats[stream_name] = {
                        "failed_events_count": 0
                    }
            
            return {
                "total_failed_events": total_failed,
                "streams": stats
            }
    
    async def _update_dlq_metadata(self, stream_name: str, failure_type: str):
        """Update DLQ metadata for statistics"""
        metadata_key = f"{self.dlq_metadata_prefix}{stream_name}"
        
        # Increment failure count by type
        await self.redis.hincrby(metadata_key, failure_type, 1)
        await self.redis.hset(metadata_key, "last_failure", datetime.utcnow().isoformat())
    
    async def _scan_keys(self, pattern: str) -> List[str]:
        """Scan Redis keys matching pattern"""
        keys = []
        cursor = 0
        while True:
            cursor, batch = await self.redis.scan(cursor, match=pattern, count=100)
            keys.extend(batch)
            if cursor == 0:
                break
        return keys

