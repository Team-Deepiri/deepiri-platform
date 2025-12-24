"""
Deepiri Synapse - Central Event Streaming Hub
Manages Redis Streams and provides monitoring/management API
"""
from fastapi import FastAPI
from typing import Dict, Any, List
import redis.asyncio as redis
import os
from .streams.manager import StreamManager
from .monitoring.metrics_collector import MetricsCollector

app = FastAPI(
    title="Deepiri Synapse",
    description="Central streaming service for event-driven architecture",
    version="0.1.0"
)

# Redis connection (shared with services)
redis_client: redis.Redis = None
stream_manager: StreamManager = None
metrics_collector: MetricsCollector = None


@app.on_event("startup")
async def startup():
    """Initialize Redis connection and managers"""
    global redis_client, stream_manager, metrics_collector
    redis_host = os.getenv("REDIS_HOST", "redis")
    redis_port = int(os.getenv("REDIS_PORT", "6379"))
    redis_password = os.getenv("REDIS_PASSWORD", "redispassword")
    
    redis_client = redis.Redis(
        host=redis_host,
        port=redis_port,
        password=redis_password,
        decode_responses=True
    )
    await redis_client.ping()
    
    # Initialize managers
    stream_manager = StreamManager(redis_client)
    metrics_collector = MetricsCollector(redis_client)
    
    # Ensure streams exist
    await stream_manager.ensure_streams_exist()


@app.on_event("shutdown")
async def shutdown():
    """Close Redis connection"""
    global redis_client
    if redis_client:
        await redis_client.close()


@app.get("/health")
async def health():
    """Health check"""
    try:
        await redis_client.ping()
        return {"status": "healthy", "service": "synapse"}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}


@app.get("/streams")
async def list_streams():
    """List all active streams with statistics"""
    stats = await stream_manager.get_all_stream_stats()
    return {"streams": stats}


@app.get("/streams/{stream_name}/info")
async def stream_info(stream_name: str):
    """Get stream information"""
    try:
        info = await redis_client.xinfo_stream(stream_name)
        return dict(info)
    except Exception as e:
        return {"error": str(e)}


@app.get("/streams/{stream_name}/messages")
async def get_messages(stream_name: str, count: int = 10):
    """Get recent messages from stream"""
    try:
        messages = await redis_client.xrevrange(stream_name, count=count)
        return {
            "stream": stream_name,
            "messages": [
                {"id": msg_id, "data": data}
                for msg_id, data in messages
            ]
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/metrics")
async def get_metrics():
    """Get streaming service metrics"""
    stats = await stream_manager.get_all_stream_stats()
    inference_metrics = await metrics_collector.get_inference_metrics()
    
    return {
        "total_streams": len(stats),
        "streams": {s["name"]: s for s in stats},
        "inference_metrics": inference_metrics
    }

