"""
Metrics collector for Synapse
Collects and aggregates streaming metrics
"""
import redis.asyncio as redis
from typing import Dict, Any, List
from datetime import datetime, timedelta


class MetricsCollector:
    """Collects metrics from streams"""
    
    def __init__(self, redis_client: redis.Redis):
        """Initialize metrics collector"""
        self.redis = redis_client
    
    async def get_stream_metrics(
        self,
        stream_name: str,
        time_window_minutes: int = 60
    ) -> Dict[str, Any]:
        """Get metrics for a stream over time window"""
        try:
            # Get recent messages
            cutoff_time = datetime.utcnow() - timedelta(minutes=time_window_minutes)
            cutoff_id = int(cutoff_time.timestamp() * 1000)
            
            messages = await self.redis.xrange(
                stream_name,
                min=f"{cutoff_id}-0",
                count=1000
            )
            
            return {
                "stream": stream_name,
                "message_count": len(messages),
                "time_window_minutes": time_window_minutes,
                "messages_per_minute": len(messages) / time_window_minutes if time_window_minutes > 0 else 0
            }
        except Exception as e:
            return {"error": str(e)}
    
    async def get_inference_metrics(self, time_window_minutes: int = 60) -> Dict[str, Any]:
        """Get aggregated inference metrics"""
        try:
            cutoff_time = datetime.utcnow() - timedelta(minutes=time_window_minutes)
            cutoff_id = int(cutoff_time.timestamp() * 1000)
            
            messages = await self.redis.xrange(
                "inference-events",
                min=f"{cutoff_id}-0",
                count=1000
            )
            
            if not messages:
                return {
                    "total_inferences": 0,
                    "avg_latency_ms": 0,
                    "total_tokens": 0
                }
            
            latencies = []
            total_tokens = 0
            
            for msg_id, data in messages:
                if "latency_ms" in data:
                    latencies.append(float(data["latency_ms"]))
                if "tokens_used" in data:
                    total_tokens += int(data.get("tokens_used", 0))
            
            return {
                "total_inferences": len(messages),
                "avg_latency_ms": sum(latencies) / len(latencies) if latencies else 0,
                "total_tokens": total_tokens,
                "time_window_minutes": time_window_minutes
            }
        except Exception as e:
            return {"error": str(e)}

