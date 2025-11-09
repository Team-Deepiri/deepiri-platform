"""
Session Routes
Session recording and analysis endpoints
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import List, Dict, Optional
from ..services.session_analyzer import get_session_analyzer
from ..logging_config import get_logger, ErrorLogger

router = APIRouter()
logger = get_logger("pyagent.session")
error_logger = ErrorLogger()


class SessionEvent(BaseModel):
    timestamp: str
    type: str
    data: Dict


class SessionRequest(BaseModel):
    user_id: str
    events: List[SessionEvent]
    start_time: str
    end_time: Optional[str] = None


@router.post("/session/analyze")
async def analyze_session(req: SessionRequest, request: Request):
    """Analyze session and generate insights."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        analyzer = get_session_analyzer()
        
        session_data = {
            'user_id': req.user_id,
            'events': [e.dict() for e in req.events],
            'start_time': req.start_time,
            'end_time': req.end_time
        }
        
        insights = analyzer.analyze_session(session_data)
        
        return {
            'success': True,
            'data': insights,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/session/analyze")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/session/summary")
async def generate_summary(request: Request):
    """Generate session summary."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        session_data = body.get('session')
        
        if not session_data:
            raise HTTPException(status_code=400, detail="Session data required")
        
        analyzer = get_session_analyzer()
        insights = analyzer.analyze_session(session_data)
        
        summary = {
            'duration': 'N/A',
            'productivity_score': insights.get('productivity_score', 0.0),
            'challenges_completed': insights.get('challenge_performance', {}).get('completed', 0),
            'recommendations': insights.get('recommendations', [])
        }
        
        return {
            'success': True,
            'data': summary,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/session/summary")
        raise HTTPException(status_code=500, detail=str(e))

