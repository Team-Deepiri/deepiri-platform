"""
Inference Routes
Model inference endpoints
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import List, Optional
from ..services.inference_service import get_inference_service
from ..services.embedding_service import get_embedding_service
from ..logging_config import get_logger, ErrorLogger

router = APIRouter()
logger = get_logger("pyagent.inference")
error_logger = ErrorLogger()


class InferenceRequest(BaseModel):
    prompt: str
    max_length: int = 100
    temperature: float = 0.7
    use_cache: bool = True


class BatchInferenceRequest(BaseModel):
    prompts: List[str]
    max_length: int = 100


class EmbeddingRequest(BaseModel):
    text: str
    use_cache: bool = True


@router.post("/inference/generate")
async def generate_text(req: InferenceRequest, request: Request):
    """Generate text using inference service."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        service = get_inference_service()
        result = await service.generate(
            req.prompt,
            max_length=req.max_length,
            use_cache=req.use_cache
        )
        
        return {
            'success': True,
            'data': {'generated_text': result},
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/inference/generate")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/inference/batch")
async def batch_generate(req: BatchInferenceRequest, request: Request):
    """Batch text generation."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        service = get_inference_service()
        results = await service.batch_generate(
            req.prompts,
            max_length=req.max_length
        )
        
        return {
            'success': True,
            'data': {'results': results},
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/inference/batch")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/embedding/generate")
async def generate_embedding(req: EmbeddingRequest, request: Request):
    """Generate text embedding."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        service = get_embedding_service()
        embedding = service.embed(req.text, use_cache=req.use_cache)
        
        return {
            'success': True,
            'data': {
                'embedding': embedding.tolist(),
                'dimension': len(embedding)
            },
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/embedding/generate")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/embedding/similarity")
async def compute_similarity(request: Request):
    """Compute similarity between two texts."""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    try:
        body = await request.json()
        text1 = body.get('text1')
        text2 = body.get('text2')
        
        if not text1 or not text2:
            raise HTTPException(status_code=400, detail="Both text1 and text2 required")
        
        service = get_embedding_service()
        similarity = service.similarity(text1, text2)
        
        return {
            'success': True,
            'data': {'similarity': similarity},
            'request_id': request_id
        }
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/embedding/similarity")
        raise HTTPException(status_code=500, detail=str(e))

