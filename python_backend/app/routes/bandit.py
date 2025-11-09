"""
Bandit Routes
Multi-armed bandit API endpoints
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Dict, Optional
from ..services.bandit_service import get_bandit_service
from ..logging_config import get_logger, ErrorLogger

router = APIRouter()
logger = get_logger("pyagent.bandit")
error_logger = ErrorLogger()


class BanditSelectRequest(BaseModel):
    user_id: str
    context: Dict


class BanditUpdateRequest(BaseModel):
    user_id: str
    challenge_type: str
    reward: float
    context: Dict


@router.post("/bandit/select")
async def select_challenge(req: BanditSelectRequest, request: Request):
    """Select challenge using bandit."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        service = get_bandit_service()
        challenge_type = await service.select_challenge(req.user_id, req.context)
        
        return {
            'success': True,
            'data': {'challenge_type': challenge_type},
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/bandit/select")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bandit/update")
async def update_bandit(req: BanditUpdateRequest, request: Request):
    """Update bandit with reward."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        service = get_bandit_service()
        await service.update_bandit(
            req.user_id,
            req.challenge_type,
            req.reward,
            req.context
        )
        
        return {
            'success': True,
            'message': 'Bandit updated',
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/bandit/update")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/bandit/stats/{user_id}")
async def get_bandit_stats(user_id: str, request: Request):
    """Get bandit statistics."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        service = get_bandit_service()
        bandit = service.get_bandit(user_id)
        stats = bandit.get_statistics()
        
        return {
            'success': True,
            'data': stats,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/bandit/stats")
        raise HTTPException(status_code=500, detail=str(e))

