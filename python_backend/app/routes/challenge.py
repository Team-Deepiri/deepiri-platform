from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import openai
from ..settings import settings
from ..logging_config import get_logger, ErrorLogger
from ..services.challenge_generator import get_challenge_generator
from ..services.task_classifier import get_task_classifier
import time
import json
import asyncio

router = APIRouter()
logger = get_logger("pyagent.challenge")
error_logger = ErrorLogger()


class TaskInput(BaseModel):
    title: str
    description: Optional[str] = None
    type: Optional[str] = "manual"
    estimatedDuration: Optional[int] = None


class ChallengeGenerateRequest(BaseModel):
    task: TaskInput


class ChallengeResponse(BaseModel):
    success: bool
    data: Dict[str, Any]
    request_id: str


@router.post("/challenge/generate", response_model=ChallengeResponse)
async def generate_challenge(req: ChallengeGenerateRequest, request: Request):
    """
    Generate a gamified challenge from a task using AI.
    
    Args:
        req: Challenge generation request with task data
        request: FastAPI request object for logging
        
    Returns:
        ChallengeResponse with generated challenge data
    """
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    logger.info("Generating challenge from task", 
                request_id=request_id, 
                task_title=req.task.title)

    try:
        start_time = time.time()
        
        # Use the new challenge generator service
        challenge_generator = get_challenge_generator()
        
        # Prepare task dict
        task_dict = {
            'title': req.task.title,
            'description': req.task.description,
            'type': req.task.type,
            'estimatedDuration': req.task.estimatedDuration
        }
        
        # Generate challenge
        challenge_data = await challenge_generator.generate_challenge(task_dict)
        
        generation_time = time.time() - start_time
        
        # Add metadata
        challenge_data['aiMetadata'] = {
            'generationTime': generation_time,
            'request_id': request_id
        }

        logger.info("Challenge generated successfully",
                   request_id=request_id,
                   challenge_type=challenge_data.get('type'),
                   generation_time_ms=generation_time * 1000)

        return ChallengeResponse(
            success=True,
            data=challenge_data,
            request_id=request_id
        )
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/agent/challenge/generate")
        logger.error("Unexpected error in challenge generation", request_id=request_id, error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/task/classify")
async def classify_task(request: Request):
    """
    Classify a task to understand its type and complexity.
    Supports both web app and desktop IDE.
    """
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        task_text = body.get('task', '')
        description = body.get('description')
        
        if not task_text:
            raise HTTPException(status_code=400, detail="Task text is required")
        
        classifier = get_task_classifier()
        classification = await classifier.classify_task(task_text, description)
        
        return {
            'success': True,
            'classification': classification,
            'request_id': request_id
        }
        
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/task/classify")
        logger.error("Task classification error", request_id=request_id, error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")


