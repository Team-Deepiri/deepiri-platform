"""
Monitoring Routes
Performance and health monitoring endpoints
"""
from fastapi import APIRouter, Request
from ..services.performance_monitor import get_performance_monitor
from ..logging_config import get_logger

router = APIRouter()
logger = get_logger("pyagent.monitoring")


@router.get("/monitoring/stats")
async def get_performance_stats(request: Request):
    """Get performance statistics."""
    monitor = get_performance_monitor()
    stats = monitor.get_stats()
    
    return {
        'success': True,
        'data': stats
    }


@router.get("/monitoring/alerts")
async def get_alerts(request: Request):
    """Get performance alerts."""
    monitor = get_performance_monitor()
    alerts = monitor.check_alerts()
    
    return {
        'success': True,
        'data': {'alerts': alerts}
    }

