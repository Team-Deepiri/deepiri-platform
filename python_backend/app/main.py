from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from .routes.agent import router as agent_router
from .routes.challenge import router as challenge_router
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
    logger.info("Starting Deepiri AI Challenge Service API", version="3.0.0")
    
    # Validate required settings
    if not settings.OPENAI_API_KEY:
        logger.warning("OPENAI_API_KEY not configured - AI features will be disabled")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Deepiri AI Challenge Service API")


app = FastAPI(
    title="Deepiri AI Challenge Service API", 
    version="3.0.0",
    lifespan=lifespan
)

# CORS configuration - support both web app and desktop IDE
cors_origins = [settings.CORS_ORIGIN] if settings.CORS_ORIGIN else []
# Add common desktop IDE origins
cors_origins.extend([
    "http://localhost:5173",  # Vite dev server
    "http://localhost:3000",  # React dev server
    "file://",  # Electron file protocol
    "app://",   # Electron app protocol
])

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
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
        # Allow requests from desktop IDE (Electron) and web app
        if not path.startswith("/health") and not path.startswith("/metrics"):
            api_key = request.headers.get("x-api-key")
            # Check if request is from desktop IDE (has x-desktop-client header) or has valid API key
            is_desktop_client = request.headers.get("x-desktop-client") == "true"
            
            if settings.PYAGENT_API_KEY:
                # Desktop IDE can use API key or be identified by header
                if not is_desktop_client and api_key != settings.PYAGENT_API_KEY:
                    error_logger.log_api_error(
                        HTTPException(status_code=401, detail="Invalid API key"),
                        request_id,
                        path
                    )
                    raise HTTPException(status_code=401, detail="Invalid API key")
                # Desktop IDE with API key is always allowed
                elif is_desktop_client and api_key and api_key != settings.PYAGENT_API_KEY:
                    # Desktop IDE must have valid API key
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
        "version": "3.0.0",
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
        "message": "Deepiri AI Challenge Service API",
        "version": "3.0.0",
        "docs": "/docs",
        "health": "/health",
        "metrics": "/metrics"
    }


# Include routers
app.include_router(agent_router, prefix="/agent", tags=["agent"])
app.include_router(challenge_router, prefix="/agent", tags=["challenge"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        log_level=settings.LOG_LEVEL.lower(),
        reload=True
    )
