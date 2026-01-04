"""
Deepiri Synapse - Central Event Streaming Hub
Manages Redis Streams and provides monitoring/management API
"""
from fastapi import FastAPI
from typing import Dict, Any, List
import redis.asyncio as redis
import os
import asyncio
import logging
from .streams.manager import StreamManager
from .monitoring.metrics_collector import MetricsCollector

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Deepiri Synapse",
    description="Central streaming service for event-driven architecture",
    version="0.1.0"
)

# Redis connection (shared with services)
redis_client: redis.Redis = None
stream_manager: StreamManager = None
metrics_collector: MetricsCollector = None


async def wait_for_redis(
    redis_client: redis.Redis,
    max_retries: int = 30,
    retry_delay: float = 1.0
) -> bool:
    """
    Wait for Redis to be ready with exponential backoff.
    
    Args:
        redis_client: Redis client instance
        max_retries: Maximum number of retry attempts
        retry_delay: Initial delay between retries in seconds
    
    Returns:
        True if Redis is ready, False if max retries exceeded
    """
    for attempt in range(max_retries):
        try:
            await redis_client.ping()
            logger.info(f"✓ Redis connection established (attempt {attempt + 1})")
            return True
        except (redis.ConnectionError, ConnectionRefusedError, OSError) as e:
            if attempt < max_retries - 1:
                delay = retry_delay * (2 ** min(attempt, 5))  # Exponential backoff, max 32s
                logger.warning(
                    f"Redis not ready (attempt {attempt + 1}/{max_retries}), "
                    f"retrying in {delay:.1f}s... Error: {e}"
                )
                await asyncio.sleep(delay)
            else:
                logger.error(f"Failed to connect to Redis after {max_retries} attempts: {e}")
                return False
        except Exception as e:
            logger.error(f"Unexpected error connecting to Redis: {e}")
            return False
    return False


@app.on_event("startup")
async def startup():
    """Initialize Redis connection and managers"""
    global redis_client, stream_manager, metrics_collector
    redis_host = os.getenv("REDIS_HOST", "redis")
    redis_port = int(os.getenv("REDIS_PORT", "6379"))
    redis_password = os.getenv("REDIS_PASSWORD", "redispassword")
    
    logger.info(f"Connecting to Redis at {redis_host}:{redis_port}...")
    
    redis_client = redis.Redis(
        host=redis_host,
        port=redis_port,
        password=redis_password,
        decode_responses=True
    )
    
    # Wait for Redis to be ready with retry logic
    if not await wait_for_redis(redis_client):
        raise RuntimeError("Failed to connect to Redis. Please ensure Redis is running and accessible.")
    
    # Initialize managers
    logger.info("Initializing stream manager and metrics collector...")
    stream_manager = StreamManager(redis_client)
    metrics_collector = MetricsCollector(redis_client)
    
    # Ensure streams exist
    await stream_manager.ensure_streams_exist()
    logger.info("✓ Synapse startup complete")


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

