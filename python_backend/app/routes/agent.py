from fastapi import APIRouter, HTTPException, Request, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, AsyncGenerator
import openai
import httpx
import asyncio
from ..settings import settings
from ..logging_config import get_logger, ErrorLogger
import time

router = APIRouter()
logger = get_logger("pyagent.agent")
error_logger = ErrorLogger()


class MessageRequest(BaseModel):
    session_id: Optional[str] = None
    content: str = Field(..., min_length=1, max_length=4000)
    temperature: Optional[float] = Field(None, ge=0.0, le=2.0)
    max_tokens: Optional[int] = Field(None, ge=1, le=4000)


class MessageResponse(BaseModel):
    success: bool
    data: dict
    request_id: str


def get_request_id(request: Request) -> str:
    """Extract request ID from request state."""
    return getattr(request.state, 'request_id', 'unknown')


@router.post("/message", response_model=MessageResponse)
async def agent_message(req: MessageRequest, request: Request):
    """
    Send a message to the AI agent and get a response.
    
    Args:
        req: Message request with content and optional parameters
        request: FastAPI request object for logging
        
    Returns:
        MessageResponse with AI-generated content
    """
    request_id = get_request_id(request)
    
    if not settings.OPENAI_API_KEY:
        logger.error("OPENAI_API_KEY not configured", request_id=request_id)
        raise HTTPException(status_code=503, detail="AI service not configured")

    logger.info("Processing agent message", 
                request_id=request_id, 
                session_id=req.session_id,
                content_length=len(req.content))

    try:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        
        # Prepare messages with system prompt
        messages = [
            {
                "role": "system", 
                "content": "You are tripblip Agent, an AI assistant that helps users discover and plan local adventures. Be concise, helpful, and encouraging. Focus on outdoor activities, local events, and unique experiences."
            },
            {"role": "user", "content": req.content}
        ]

        # Prepare completion parameters
        completion_params = {
            "model": settings.OPENAI_MODEL,
            "messages": messages,
            "temperature": req.temperature or settings.AI_TEMPERATURE,
            "max_tokens": req.max_tokens or settings.AI_MAX_TOKENS,
            "top_p": settings.AI_TOP_P
        }

        start_time = time.time()
        completion = await asyncio.to_thread(
            client.chat.completions.create,
            **completion_params
        )
        duration = time.time() - start_time

        response_data = {
            "session_id": req.session_id,
            "message": completion.choices[0].message.content,
            "tokens": completion.usage.total_tokens if completion.usage else 0,
            "model": completion.model,
            "processing_time_ms": duration * 1000
        }

        logger.info("Agent message processed successfully",
                   request_id=request_id,
                   tokens_used=response_data["tokens"],
                   processing_time_ms=response_data["processing_time_ms"])

        return MessageResponse(
            success=True,
            data=response_data,
            request_id=request_id
        )

    except openai.RateLimitError as e:
        logger.error("OpenAI rate limit exceeded", request_id=request_id, error=str(e))
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Please try again later.")
    
    except openai.AuthenticationError as e:
        logger.error("OpenAI authentication failed", request_id=request_id, error=str(e))
        raise HTTPException(status_code=503, detail="AI service authentication failed")
    
    except openai.APIError as e:
        logger.error("OpenAI API error", request_id=request_id, error=str(e))
        raise HTTPException(status_code=502, detail="AI service temporarily unavailable")
    
    except Exception as e:
        error_logger.log_api_error(e, request_id, "/agent/message")
        logger.error("Unexpected error in agent message", request_id=request_id, error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/message/stream")
async def agent_message_stream(req: MessageRequest, request: Request):
    """
    Send a message to the AI agent and get a streaming response.
    
    Args:
        req: Message request with content and optional parameters
        request: FastAPI request object for logging
        
    Returns:
        StreamingResponse with AI-generated content chunks
    """
    request_id = get_request_id(request)
    
    if not settings.OPENAI_API_KEY:
        logger.error("OPENAI_API_KEY not configured for streaming", request_id=request_id)
        raise HTTPException(status_code=503, detail="AI service not configured")

    logger.info("Processing streaming agent message", 
                request_id=request_id, 
                session_id=req.session_id,
                content_length=len(req.content))

    async def event_generator() -> AsyncGenerator[str, None]:
        """Generate streaming response chunks."""
        try:
            client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
            
            messages = [
                {
                    "role": "system", 
                    "content": "You are tripblip Agent, an AI assistant that helps users discover and plan local adventures. Be concise, helpful, and encouraging. Focus on outdoor activities, local events, and unique experiences."
                },
                {"role": "user", "content": req.content}
            ]

            stream_params = {
                "model": settings.OPENAI_MODEL,
                "messages": messages,
                "temperature": req.temperature or settings.AI_TEMPERATURE,
                "max_tokens": req.max_tokens or settings.AI_MAX_TOKENS,
                "top_p": settings.AI_TOP_P,
                "stream": True
            }

            # Use asyncio.to_thread for the streaming call
            stream = await asyncio.to_thread(
                client.chat.completions.create,
                **stream_params
            )

            chunk_count = 0
            for chunk in stream:
                if chunk.choices and chunk.choices[0].delta.content:
                    content = chunk.choices[0].delta.content
                    chunk_count += 1
                    yield content

            logger.info("Streaming completed successfully",
                       request_id=request_id,
                       chunks_sent=chunk_count)

        except openai.RateLimitError as e:
            logger.error("OpenAI rate limit exceeded in stream", request_id=request_id, error=str(e))
            yield f"\n[ERROR] Rate limit exceeded. Please try again later."
        
        except openai.AuthenticationError as e:
            logger.error("OpenAI authentication failed in stream", request_id=request_id, error=str(e))
            yield f"\n[ERROR] AI service authentication failed."
        
        except openai.APIError as e:
            logger.error("OpenAI API error in stream", request_id=request_id, error=str(e))
            yield f"\n[ERROR] AI service temporarily unavailable."
        
        except Exception as e:
            error_logger.log_api_error(e, request_id, "/agent/message/stream")
            logger.error("Unexpected error in streaming", request_id=request_id, error=str(e))
            yield f"\n[ERROR] Internal server error."

    return StreamingResponse(
        event_generator(), 
        media_type="text/plain",
        headers={"X-Request-ID": request_id}
    )


@router.get("/tools/external/adventure-data")
async def proxy_adventure_data(
    lat: float, 
    lng: float, 
    radius: int = 5000, 
    interests: Optional[str] = None,
    request: Request = None
):
    """Proxy adventure data requests to the Node.js backend."""
    request_id = get_request_id(request) if request else "unknown"
    
    logger.info("Proxying adventure data request",
               request_id=request_id,
               lat=lat, lng=lng, radius=radius, interests=interests)

    url = f"{settings.NODE_BACKEND_URL}/api/external/adventure-data"
    params = {"lat": lat, "lng": lng, "radius": radius}
    if interests:
        params["interests"] = interests

    try:
        async with httpx.AsyncClient(timeout=settings.REQUEST_TIMEOUT) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            
            logger.info("Adventure data proxy successful",
                       request_id=request_id,
                       status_code=response.status_code)
            
            return response.json()
    
    except httpx.TimeoutException:
        logger.error("Timeout in adventure data proxy", request_id=request_id)
        raise HTTPException(status_code=504, detail="Backend service timeout")
    
    except httpx.HTTPStatusError as e:
        logger.error("HTTP error in adventure data proxy", 
                    request_id=request_id, 
                    status_code=e.response.status_code)
        raise HTTPException(status_code=e.response.status_code, detail=f"Backend error: {e.response.text}")
    
    except httpx.RequestError as e:
        logger.error("Request error in adventure data proxy", request_id=request_id, error=str(e))
        raise HTTPException(status_code=502, detail="Backend service unavailable")


@router.get("/tools/external/directions")
async def proxy_directions(
    fromLat: float, 
    fromLng: float, 
    toLat: float, 
    toLng: float, 
    mode: str = "walking",
    request: Request = None
):
    """Proxy directions requests to the Node.js backend."""
    request_id = get_request_id(request) if request else "unknown"
    
    logger.info("Proxying directions request",
               request_id=request_id,
               from_lat=fromLat, from_lng=fromLng,
               to_lat=toLat, to_lng=toLng, mode=mode)

    url = f"{settings.NODE_BACKEND_URL}/api/external/directions"
    params = {
        "fromLat": fromLat, 
        "fromLng": fromLng, 
        "toLat": toLat, 
        "toLng": toLng, 
        "mode": mode
    }

    try:
        async with httpx.AsyncClient(timeout=settings.REQUEST_TIMEOUT) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            
            logger.info("Directions proxy successful",
                       request_id=request_id,
                       status_code=response.status_code)
            
            return response.json()
    
    except httpx.TimeoutException:
        logger.error("Timeout in directions proxy", request_id=request_id)
        raise HTTPException(status_code=504, detail="Backend service timeout")
    
    except httpx.HTTPStatusError as e:
        logger.error("HTTP error in directions proxy", 
                    request_id=request_id, 
                    status_code=e.response.status_code)
        raise HTTPException(status_code=e.response.status_code, detail=f"Backend error: {e.response.text}")
    
    except httpx.RequestError as e:
        logger.error("Request error in directions proxy", request_id=request_id, error=str(e))
        raise HTTPException(status_code=502, detail="Backend service unavailable")


@router.get("/tools/external/weather/current")
async def proxy_weather_current(lat: float, lng: float, request: Request = None):
    """Proxy current weather requests to the Node.js backend."""
    request_id = get_request_id(request) if request else "unknown"
    
    logger.info("Proxying current weather request",
               request_id=request_id, lat=lat, lng=lng)

    url = f"{settings.NODE_BACKEND_URL}/api/external/weather/current"
    params = {"lat": lat, "lng": lng}

    try:
        async with httpx.AsyncClient(timeout=settings.REQUEST_TIMEOUT) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            
            logger.info("Current weather proxy successful",
                       request_id=request_id,
                       status_code=response.status_code)
            
            return response.json()
    
    except httpx.TimeoutException:
        logger.error("Timeout in current weather proxy", request_id=request_id)
        raise HTTPException(status_code=504, detail="Backend service timeout")
    
    except httpx.HTTPStatusError as e:
        logger.error("HTTP error in current weather proxy", 
                    request_id=request_id, 
                    status_code=e.response.status_code)
        raise HTTPException(status_code=e.response.status_code, detail=f"Backend error: {e.response.text}")
    
    except httpx.RequestError as e:
        logger.error("Request error in current weather proxy", request_id=request_id, error=str(e))
        raise HTTPException(status_code=502, detail="Backend service unavailable")


@router.get("/tools/external/weather/forecast")
async def proxy_weather_forecast(
    lat: float, 
    lng: float, 
    days: int = 1,
    request: Request = None
):
    """Proxy weather forecast requests to the Node.js backend."""
    request_id = get_request_id(request) if request else "unknown"
    
    logger.info("Proxying weather forecast request",
               request_id=request_id, lat=lat, lng=lng, days=days)

    url = f"{settings.NODE_BACKEND_URL}/api/external/weather/forecast"
    params = {"lat": lat, "lng": lng, "days": days}

    try:
        async with httpx.AsyncClient(timeout=settings.REQUEST_TIMEOUT) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            
            logger.info("Weather forecast proxy successful",
                       request_id=request_id,
                       status_code=response.status_code)
            
            return response.json()
    
    except httpx.TimeoutException:
        logger.error("Timeout in weather forecast proxy", request_id=request_id)
        raise HTTPException(status_code=504, detail="Backend service timeout")
    
    except httpx.HTTPStatusError as e:
        logger.error("HTTP error in weather forecast proxy", 
                    request_id=request_id, 
                    status_code=e.response.status_code)
        raise HTTPException(status_code=e.response.status_code, detail=f"Backend error: {e.response.text}")
    
    except httpx.RequestError as e:
        logger.error("Request error in weather forecast proxy", request_id=request_id, error=str(e))
        raise HTTPException(status_code=502, detail="Backend service unavailable")


