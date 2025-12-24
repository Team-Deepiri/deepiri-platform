"""
Stream manager for Synapse
Handles stream lifecycle, monitoring, and management
"""
import redis.asyncio as redis
from typing import Dict, Any, List, Optional
from datetime import datetime


class StreamManager:
    """Manages Redis Streams lifecycle and operations"""
    
    def __init__(self, redis_client: redis.Redis):
        """Initialize stream manager"""
        self.redis = redis_client
        self.streams = [
            "model-events",
            "inference-events",
            "platform-events",
            "agi-decisions",
            "training-events"
        ]
    
    async def ensure_streams_exist(self):
        """Ensure all required streams exist"""
        for stream in self.streams:
            try:
                await self.redis.xinfo_stream(stream)
            except redis.ResponseError:
                # Stream doesn't exist, create it with an empty message
                await self.redis.xadd(stream, {"created": datetime.utcnow().isoformat()})
    
    async def get_stream_stats(self, stream_name: str) -> Dict[str, Any]:
        """Get statistics for a stream"""
        try:
            info = await self.redis.xinfo_stream(stream_name)
            length = await self.redis.xlen(stream_name)
            
            return {
                "name": stream_name,
                "length": length,
                "groups": info.get("groups", 0),
                "first_entry": info.get("first-entry"),
                "last_entry": info.get("last-entry")
            }
        except Exception as e:
            return {"error": str(e)}
    
    async def get_all_stream_stats(self) -> List[Dict[str, Any]]:
        """Get statistics for all streams"""
        stats = []
        for stream in self.streams:
            stat = await self.get_stream_stats(stream)
            stats.append(stat)
        return stats
    
    async def trim_stream(self, stream_name: str, max_length: int = 10000):
        """Trim stream to max length"""
        await self.redis.xtrim(stream_name, maxlen=max_length, approximate=True)
    
    async def create_consumer_group(
        self,
        stream_name: str,
        group_name: str,
        start_id: str = "0"
    ):
        """Create consumer group for stream"""
        try:
            await self.redis.xgroup_create(
                stream_name,
                group_name,
                id=start_id,
                mkstream=True
            )
            return True
        except redis.ResponseError as e:
            if "BUSYGROUP" in str(e):
                return True  # Group already exists
            raise

