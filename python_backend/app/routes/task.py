"""
Task Management Routes
Full CRUD operations for tasks with AI classification
"""
from fastapi import APIRouter, HTTPException, Request, Depends
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from ..services.task_classifier import get_task_classifier
from ..services.multimodal_understanding import get_multimodal_understanding
from ..logging_config import get_logger, ErrorLogger

router = APIRouter()
logger = get_logger("pyagent.task")
error_logger = ErrorLogger()


class TaskCreateRequest(BaseModel):
    title: str
    description: Optional[str] = None
    type: Optional[str] = None
    estimated_duration: Optional[int] = None
    metadata: Optional[Dict[str, Any]] = None


class TaskUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class TaskResponse(BaseModel):
    success: bool
    data: Dict[str, Any]
    request_id: str


@router.post("/task/create", response_model=TaskResponse)
async def create_task(req: TaskCreateRequest, request: Request):
    """Create a new task with automatic classification."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        classifier = get_task_classifier()
        
        classification = await classifier.classify_task(
            req.title,
            req.description
        )
        
        task_data = {
            'title': req.title,
            'description': req.description,
            'type': req.type or classification.get('type', 'manual'),
            'estimated_duration': req.estimated_duration or classification.get('estimated_duration', 30),
            'classification': classification,
            'metadata': req.metadata or {},
            'status': 'pending'
        }
        
        logger.info("Task created", request_id=request_id, task_title=req.title)
        
        return TaskResponse(
            success=True,
            data=task_data,
            request_id=request_id
        )
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/task/create")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/task/classify", response_model=TaskResponse)
async def classify_task(request: Request):
    """Classify a task to understand its type and complexity."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        task_text = body.get('task', '')
        description = body.get('description')
        
        if not task_text:
            raise HTTPException(status_code=400, detail="Task text is required")
        
        classifier = get_task_classifier()
        classification = await classifier.classify_task(task_text, description)
        
        return TaskResponse(
            success=True,
            data={'classification': classification},
            request_id=request_id
        )
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/task/classify")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/task/multimodal")
async def understand_multimodal_task(request: Request):
    """Understand task from multiple input types (text, image, code, etc.)."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        content = body.get('content')
        modality = body.get('modality', 'text')
        metadata = body.get('metadata')
        
        if not content:
            raise HTTPException(status_code=400, detail="Content is required")
        
        multimodal = get_multimodal_understanding()
        understanding = await multimodal.understand_task(content, modality, metadata)
        
        return {
            'success': True,
            'data': understanding,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/task/multimodal")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/task/batch-classify")
async def batch_classify_tasks(request: Request):
    """Classify multiple tasks at once."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        tasks = body.get('tasks', [])
        
        if not tasks:
            raise HTTPException(status_code=400, detail="Tasks array is required")
        
        classifier = get_task_classifier()
        results = await classifier.batch_classify(tasks)
        
        return {
            'success': True,
            'data': results,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/task/batch-classify")
        raise HTTPException(status_code=500, detail=str(e))

