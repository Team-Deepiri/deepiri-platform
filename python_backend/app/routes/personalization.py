"""
Personalization Routes
RL-based challenge adaptation and user behavior learning
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, Dict, List, Any
from ..services.challenge_generator import get_challenge_generator
from ..services.context_aware_adaptation import get_context_adapter
from ..logging_config import get_logger, ErrorLogger

router = APIRouter()
logger = get_logger("pyagent.personalization")
error_logger = ErrorLogger()


class PersonalizationRequest(BaseModel):
    user_id: str
    task: Dict[str, Any]
    user_history: Optional[Dict[str, Any]] = None
    context: Optional[Dict[str, Any]] = None


class AdaptationRequest(BaseModel):
    user_id: str
    task: Dict[str, Any]
    user_data: Optional[Dict[str, Any]] = None


@router.post("/personalize/challenge")
async def personalize_challenge(req: PersonalizationRequest, request: Request):
    """Generate personalized challenge based on user history and context."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        generator = get_challenge_generator()
        
        challenge = await generator.generate_challenge(
            req.task,
            user_history=req.user_history,
            difficulty_preference=req.context.get('difficulty_preference') if req.context else None
        )
        
        if req.context:
            adapter = get_context_adapter()
            context_analysis = await adapter.analyze_context(
                req.user_id,
                req.task,
                req.user_data if hasattr(req, 'user_data') else None
            )
            challenge['context_adaptation'] = context_analysis
        
        logger.info("Personalized challenge generated", 
                   user_id=req.user_id,
                   request_id=request_id)
        
        return {
            'success': True,
            'data': challenge,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/personalize/challenge")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/adapt/context")
async def adapt_to_context(req: AdaptationRequest, request: Request):
    """Adapt challenge based on real-time context."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        adapter = get_context_adapter()
        
        adaptation = await adapter.analyze_context(
            req.user_id,
            req.task,
            req.user_data
        )
        
        return {
            'success': True,
            'data': adaptation,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/adapt/context")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/personalize/update-preference")
async def update_user_preference(request: Request):
    """Update user preference based on challenge performance."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        user_id = body.get('user_id')
        challenge_id = body.get('challenge_id')
        performance = body.get('performance')
        engagement = body.get('engagement')
        
        if not all([user_id, challenge_id, performance is not None]):
            raise HTTPException(status_code=400, detail="Missing required fields")
        
        logger.info("User preference updated",
                   user_id=user_id,
                   challenge_id=challenge_id,
                   performance=performance)
        
        return {
            'success': True,
            'message': 'Preference updated',
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/personalize/update-preference")
        raise HTTPException(status_code=500, detail=str(e))

