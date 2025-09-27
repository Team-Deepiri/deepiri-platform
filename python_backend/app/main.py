from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from .routes.agent import router as agent_router
from .settings import settings
from .logging_config import get_logger, RequestLogger, ErrorLogger
import time
import uuid
import logging
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from contextlib import asynccontextmanager
import asyncio
from typing import AsyncGenerator

# Initialize loggers
logger = get_logger("pyagent.main")
request_logger = RequestLogger()
error_logger = ErrorLogger()

# Prometheus metrics
REQ_COUNTER = Counter("pyagent_requests_total", "Total requests", ["path", "method", "status"])
REQ_LATENCY = Histogram("pyagent_request_duration_seconds", "Request latency", ["path", "method"])
ERROR_COUNTER = Counter("pyagent_errors_total", "Total errors", ["error_type", "endpoint"])


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan manager for startup/shutdown events."""
    # Startup
    logger.info("Starting Python Agent API", version="0.1.0")
    
    # Validate required settings
    if not settings.OPENAI_API_KEY:
        logger.warning("OPENAI_API_KEY not configured - AI features will be disabled")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Python Agent API")


app = FastAPI(
    title="tripblip Python Agent API", 
    version="0.1.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.CORS_ORIGIN],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_request_id_and_metrics(request: Request, call_next):
    """Middleware for request ID generation, metrics collection, and logging."""
    request_id = str(uuid.uuid4())
    start = time.time()
    path = request.url.path
    method = request.method
    response = None
    
    # Add request ID to request state
    request.state.request_id = request_id
    
    try:
        # API key guard for non-health/metrics endpoints
        if not path.startswith("/health") and not path.startswith("/metrics"):
            api_key = request.headers.get("x-api-key")
            if settings.PYAGENT_API_KEY and api_key != settings.PYAGENT_API_KEY:
                error_logger.log_api_error(
                    HTTPException(status_code=401, detail="Invalid API key"),
                    request_id,
                    path
                )
                raise HTTPException(status_code=401, detail="Invalid API key")
        
        response = await call_next(request)
        return response
        
    except Exception as e:
        # Log and track errors
        error_logger.log_api_error(e, request_id, path)
        ERROR_COUNTER.labels(
            error_type=type(e).__name__,
            endpoint=path
        ).inc()
        
        # Re-raise HTTP exceptions, wrap others
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(status_code=500, detail="Internal server error")
        
    finally:
        # Record metrics and log request
        status = response.status_code if response else 500
        duration = time.time() - start
        duration_ms = duration * 1000
        
        REQ_COUNTER.labels(path=path, method=method, status=str(status)).inc()
        REQ_LATENCY.labels(path=path, method=method).observe(duration)
        
        request_logger.log_request(
            request_id=request_id,
            method=method,
            path=path,
            status_code=status,
            duration_ms=duration_ms,
            user_agent=request.headers.get("user-agent"),
            ip_address=request.client.host if request.client else None
        )


@app.get("/health")
def health():
    """Health check endpoint with detailed status information."""
    health_status = {
        "status": "healthy",
        "version": "0.1.0",
        "timestamp": time.time(),
        "services": {
            "ai": "ready" if settings.OPENAI_API_KEY else "disabled",
            "redis": "not_configured",  # TODO: Add Redis health check
            "node_backend": "not_checked"  # TODO: Add Node backend health check
        },
        "configuration": {
            "log_level": settings.LOG_LEVEL,
            "cors_origin": settings.CORS_ORIGIN,
            "max_concurrent_requests": settings.MAX_CONCURRENT_REQUESTS
        }
    }
    
    logger.info("Health check requested", **health_status)
    return health_status


@app.get("/metrics")
def metrics():
    """Prometheus metrics endpoint."""
    logger.debug("Metrics endpoint accessed")
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
def root():
    """Root endpoint with API information."""
    return {
        "message": "tripblip Python Agent API",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/health",
        "metrics": "/metrics"
    }


# Include routers
app.include_router(agent_router, prefix="/agent", tags=["agent"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        log_level=settings.LOG_LEVEL.lower(),
        reload=True
    )
