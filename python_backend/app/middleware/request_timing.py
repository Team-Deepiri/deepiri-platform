"""
Request Timing Middleware
Track request latency and performance
"""
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
import time
from ..logging_config import get_logger

logger = get_logger("middleware.timing")


class RequestTimingMiddleware(BaseHTTPMiddleware):
    """Middleware to track request timing."""
    
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        response = await call_next(request)
        
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        
        if process_time > 1.0:
            logger.warning("Slow request detected",
                          path=request.url.path,
                          method=request.method,
                          duration=process_time)
        
        return response

