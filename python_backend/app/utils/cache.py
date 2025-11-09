"""
Caching Utilities
Redis-based caching for performance
"""
import redis
import json
from typing import Optional, Any
from functools import wraps
from ..settings import settings
from ..logging_config import get_logger

logger = get_logger("utils.cache")

_redis_client = None


def get_redis_client():
    """Get Redis client singleton."""
    global _redis_client
    if _redis_client is None:
        try:
            _redis_client = redis.Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                password=settings.REDIS_PASSWORD,
                db=settings.REDIS_DB,
                decode_responses=True
            )
            _redis_client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.error("Redis connection failed", error=str(e))
            _redis_client = None
    return _redis_client


def cache_result(ttl: int = 3600, key_prefix: str = "cache"):
    """Decorator to cache function results."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            client = get_redis_client()
            if not client:
                return await func(*args, **kwargs)
            
            cache_key = f"{key_prefix}:{func.__name__}:{hash(str(args) + str(kwargs))}"
            
            cached = client.get(cache_key)
            if cached:
                return json.loads(cached)
            
            result = await func(*args, **kwargs)
            client.setex(cache_key, ttl, json.dumps(result))
            
            return result
        return wrapper
    return decorator


class CacheManager:
    """Cache manager for common operations."""
    
    @staticmethod
    def get(key: str) -> Optional[Any]:
        """Get value from cache."""
        client = get_redis_client()
        if not client:
            return None
        
        try:
            value = client.get(key)
            return json.loads(value) if value else None
        except Exception as e:
            logger.error("Cache get failed", key=key, error=str(e))
            return None
    
    @staticmethod
    def set(key: str, value: Any, ttl: int = 3600):
        """Set value in cache."""
        client = get_redis_client()
        if not client:
            return False
        
        try:
            client.setex(key, ttl, json.dumps(value))
            return True
        except Exception as e:
            logger.error("Cache set failed", key=key, error=str(e))
            return False
    
    @staticmethod
    def delete(key: str):
        """Delete key from cache."""
        client = get_redis_client()
        if not client:
            return False
        
        try:
            client.delete(key)
            return True
        except Exception as e:
            logger.error("Cache delete failed", key=key, error=str(e))
            return False
    
    @staticmethod
    def clear_pattern(pattern: str):
        """Clear all keys matching pattern."""
        client = get_redis_client()
        if not client:
            return False
        
        try:
            keys = client.keys(pattern)
            if keys:
                client.delete(*keys)
            return True
        except Exception as e:
            logger.error("Cache clear pattern failed", pattern=pattern, error=str(e))
            return False

