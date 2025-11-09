"""
RAG Routes
Retrieval-Augmented Generation for challenge generation
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, List, Dict
from ..train.infrastructure.rag_pipeline import RAGPipeline, initialize_rag_system
from ..services.challenge_generator import get_challenge_generator
from ..logging_config import get_logger, ErrorLogger

router = APIRouter()
logger = get_logger("pyagent.rag")
error_logger = ErrorLogger()

# Initialize RAG system
rag_system = None

try:
    rag_system = initialize_rag_system()
except Exception as e:
    logger.warning("RAG system not initialized", error=str(e))


class RAGQueryRequest(BaseModel):
    query: str
    task_type: Optional[str] = None
    top_k: int = 10
    rerank: bool = True


class RAGIndexRequest(BaseModel):
    challenges: List[Dict]


@router.post("/rag/query")
async def query_rag(req: RAGQueryRequest, request: Request):
    """Query RAG system for relevant challenges."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    if not rag_system:
        raise HTTPException(status_code=503, detail="RAG system not available")
    
    try:
        results = rag_system.retrieve(
            req.query,
            top_k=req.top_k,
            task_type_filter=req.task_type,
            rerank=req.rerank
        )
        
        return {
            'success': True,
            'data': results,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/rag/query")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/rag/index")
async def index_challenges(req: RAGIndexRequest, request: Request):
    """Index challenges into RAG system."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    if not rag_system:
        raise HTTPException(status_code=503, detail="RAG system not available")
    
    try:
        rag_system.add_challenges(req.challenges)
        
        return {
            'success': True,
            'message': f'Indexed {len(req.challenges)} challenges',
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/rag/index")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/rag/generate")
async def generate_with_rag(request: Request):
    """Generate challenge using RAG context."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    if not rag_system:
        raise HTTPException(status_code=503, detail="RAG system not available")
    
    try:
        body = await request.json()
        task = body.get('task')
        query = body.get('query') or task.get('title', '')
        
        retrieved = rag_system.retrieve(query, top_k=5)
        
        generator = get_challenge_generator()
        challenge = await generator.generate_challenge(task)
        
        rag_context = rag_system.generate_with_rag(task, retrieved, "")
        
        challenge['rag_context'] = {
            'retrieved_count': len(retrieved),
            'examples': retrieved[:3]
        }
        
        return {
            'success': True,
            'data': challenge,
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/rag/generate")
        raise HTTPException(status_code=500, detail=str(e))

