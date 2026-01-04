"""
Event router for Synapse
Routes events to appropriate handlers
"""
import redis.asyncio as redis
from typing import Dict, Any, Callable, Optional
import asyncio


class EventRouter:
    """Routes events to handlers"""
    
    def __init__(self, redis_client: redis.Redis):
        """Initialize event router"""
        self.redis = redis_client
        self.handlers: Dict[str, list] = {}
    
    def register_handler(
        self,
        stream_name: str,
        handler: Callable[[Dict[str, Any]], None],
        consumer_group: Optional[str] = None
    ):
        """Register event handler"""
        if stream_name not in self.handlers:
            self.handlers[stream_name] = []
        
        self.handlers[stream_name].append({
            "handler": handler,
            "consumer_group": consumer_group
        })
    
    async def start_consuming(
        self,
        stream_name: str,
        consumer_group: str,
        consumer_name: str
    ):
        """Start consuming from stream"""
        while True:
            try:
                messages = await self.redis.xreadgroup(
                    consumer_group,
                    consumer_name,
                    {stream_name: ">"},
                    count=10,
                    block=1000
                )
                
                for stream, msgs in messages:
                    for msg_id, data in msgs:
                        # Route to handlers
                        if stream_name in self.handlers:
                            for handler_info in self.handlers[stream_name]:
                                try:
                                    await handler_info["handler"](data)
                                except Exception as e:
                                    print(f"Handler error: {e}")
                        
                        # Acknowledge
                        await self.redis.xack(stream_name, consumer_group, msg_id)
            
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Consumption error: {e}")
                await asyncio.sleep(1)

