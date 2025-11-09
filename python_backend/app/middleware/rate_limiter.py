"""
Rate Limiting Middleware
Prevent API abuse with token bucket algorithm
"""
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from collections import defaultdict
import time
from typing import Dict
from ..logging_config import get_logger

logger = get_logger("middleware.ratelimit")


class TokenBucket:
    """Token bucket for rate limiting."""
    
    def __init__(self, capacity: int, refill_rate: float):
        self.capacity = capacity
        self.tokens = capacity
        self.refill_rate = refill_rate
        self.last_refill = time.time()
    
    def consume(self, tokens: int = 1) -> bool:
        """Try to consume tokens."""
        now = time.time()
        elapsed = now - self.last_refill
        self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_rate)
        self.last_refill = now
        
        if self.tokens >= tokens:
            self.tokens -= tokens
            return True
        return False


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Rate limiting middleware."""
    
    def __init__(self, app, requests_per_minute: int = 60):
        super().__init__(app)
        self.buckets: Dict[str, TokenBucket] = defaultdict(
            lambda: TokenBucket(capacity=requests_per_minute, refill_rate=requests_per_minute / 60)
        )
        self.requests_per_minute = requests_per_minute
    
    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host if request.client else "unknown"
        
        bucket = self.buckets[client_ip]
        
        if not bucket.consume():
            logger.warning("Rate limit exceeded", ip=client_ip, path=request.url.path)
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded. Please try again later."
            )
        
        response = await call_next(request)
        response.headers["X-RateLimit-Remaining"] = str(int(bucket.tokens))
        response.headers["X-RateLimit-Limit"] = str(self.requests_per_minute)
        
        return response

