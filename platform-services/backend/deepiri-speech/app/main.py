"""FastAPI entry — deepiri-speech.

Primary duplex transport: WebSocket `/v1/session/ws` (Pipecat pipeline on providers).
LiveKit is optional for WebRTC rooms/phone only.
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from pydantic import BaseModel, Field

from .bus import get_bus
from .device import resolve_device
from .livekit_worker import get_worker_state, start_worker_if_enabled, stop_worker
from .pipecat_bridge import is_available as pipecat_available
from .pipecat_bridge import status_dict as pipecat_status
from .pipeline import run_ws_session
from .providers import get_stt, get_tts
from .settings import settings
from .vad import get_vad

logging.basicConfig(level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO))
logger = logging.getLogger("deepiri-speech")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    bus = await get_bus()
    device = resolve_device()
    logger.info(
        "deepiri-speech starting stt=%s tts=%s vad=%s device=%s pipecat=%s livekit_worker=%s",
        settings.STT_PROVIDER,
        settings.TTS_PROVIDER,
        "silero" if settings.ENABLE_SILERO_VAD else "off",
        device.kind,
        pipecat_available(),
        settings.LIVEKIT_WORKER_ENABLED,
    )
    await start_worker_if_enabled()
    yield
    await stop_worker()
    await bus.close()


app = FastAPI(
    title="Deepiri Speech",
    version="0.2.0",
    description=(
        "Self-hosted STT/TTS — Poetry FastAPI, Pipecat pipeline over providers, "
        "WebSocket transport (LiveKit optional for WebRTC rooms)"
    ),
    lifespan=lifespan,
)


class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1)
    voice: Optional[str] = None
    session_id: Optional[str] = None


class SessionCreate(BaseModel):
    user_id: Optional[str] = None
    room_name: Optional[str] = None


class LiveKitTokenRequest(BaseModel):
    room_name: str
    identity: str
    name: Optional[str] = None


@app.get("/health")
async def health():
    worker = get_worker_state()
    vad = get_vad()
    device = resolve_device()
    return {
        "status": "healthy",
        "service": settings.SERVICE_NAME,
        "stt_provider": settings.STT_PROVIDER,
        "tts_provider": settings.TTS_PROVIDER,
        "vad": getattr(vad, "name", "unknown"),
        "device": device.to_dict(),
        "pipeline": "pipecat" if pipecat_available() else "native",
        "transport": "websocket",
        "livekit_optional": True,
        "livekit_url": settings.LIVEKIT_PUBLIC_URL,
        "speech_stream": settings.SPEECH_STREAM,
        "worker": worker.to_dict(),
    }


@app.get("/providers")
async def providers():
    vad = get_vad()
    device = resolve_device()
    return {
        "stt": settings.STT_PROVIDER,
        "tts": settings.TTS_PROVIDER,
        "stt_model": settings.STT_MODEL,
        "tts_voice": settings.TTS_VOICE,
        "vad": getattr(vad, "name", "unknown"),
        "silero_enabled": settings.ENABLE_SILERO_VAD,
        "pipecat_enabled": settings.PIPECAT_ENABLED,
        "pipecat_available": pipecat_available(),
        "worker_enabled": settings.LIVEKIT_WORKER_ENABLED,
        "device": device.to_dict(),
        "engines": {
            "stt_default": "faster_whisper",
            "stt_apple_edge": "whisper_cpp",
            "tts_default": "kokoro",
            "tts_avoid": "xtts_v2 (CPML)",
        },
    }


@app.get("/v1/worker/status")
async def worker_status():
    return get_worker_state().to_dict()


@app.get("/v1/pipeline/status")
async def pipeline_status():
    return {
        "transport": "websocket",
        "endpoint": "/v1/session/ws",
        "pipecat": pipecat_status(),
        "livekit_required": False,
        "note": (
            "Pipecat is in-process (not a separate service). "
            "LiveKit only for WebRTC rooms/phone — not used for default duplex."
        ),
    }


@app.post("/v1/stt")
async def stt_oneshot(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
    session_id: Optional[str] = Form(None),
):
    audio = await file.read()
    stt = get_stt()
    result = await stt.transcribe(
        audio, mime_type=file.content_type or "audio/wav", language=language
    )
    bus = await get_bus()
    await bus.stt_final(
        session_id, result.text, provider=result.provider, model=result.model
    )
    return {
        "text": result.text,
        "is_final": result.is_final,
        "language": result.language,
        "provider": result.provider,
        "model": result.model,
        "confidence": result.confidence,
    }


@app.post("/v1/tts")
async def tts_oneshot(body: TTSRequest):
    tts = get_tts()
    result = await tts.synthesize(body.text, voice=body.voice)
    bus = await get_bus()
    if body.session_id:
        from .contracts import SpeechEvent, SpeechEventType

        await bus.publish_stream(
            SpeechEvent(
                event_type=SpeechEventType.TTS_COMPLETE,
                session_id=body.session_id,
                payload={
                    "provider": result.provider,
                    "model": result.model,
                    "chars": len(body.text),
                },
            )
        )
    return Response(content=result.audio, media_type=result.mime_type)


@app.post("/v1/sessions")
async def create_session(body: SessionCreate):
    import uuid

    session_id = str(uuid.uuid4())
    room = body.room_name or f"speech-{session_id[:8]}"
    bus = await get_bus()
    await bus.session_started(session_id, user_id=body.user_id, room=room)
    return {
        "session_id": session_id,
        "room_name": room,
        "ws_url": f"ws://localhost:{settings.PORT}/v1/session/ws?session_id={session_id}",
        "transport": "websocket",
        "livekit_url": settings.LIVEKIT_PUBLIC_URL if settings.LIVEKIT_WORKER_ENABLED else None,
    }


@app.post("/v1/livekit/token")
async def livekit_token(body: LiveKitTokenRequest):
    """Optional — only when you need real WebRTC rooms/phone."""
    try:
        from livekit.api import AccessToken, VideoGrants
    except ImportError:
        return {
            "error": "livekit-api not installed; poetry install -E livekit",
            "room_name": body.room_name,
            "identity": body.identity,
            "livekit_url": settings.LIVEKIT_PUBLIC_URL,
            "dev_hint": "WS duplex does not need LiveKit; install extras only for WebRTC rooms",
        }

    token = (
        AccessToken(settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET)
        .with_identity(body.identity)
        .with_name(body.name or body.identity)
        .with_grants(
            VideoGrants(
                room_join=True,
                room=body.room_name,
                can_publish=True,
                can_subscribe=True,
            )
        )
        .to_jwt()
    )
    return {
        "token": token,
        "url": settings.LIVEKIT_PUBLIC_URL,
        "room_name": body.room_name,
        "identity": body.identity,
    }


@app.websocket("/v1/session/ws")
async def duplex_ws(websocket: WebSocket):
    """Primary media/control duplex — Pipecat pipeline on providers over WebSocket."""
    await websocket.accept()
    session_id = websocket.query_params.get("session_id") or "anon"
    bus = await get_bus()
    await bus.session_started(session_id)
    try:
        await run_ws_session(websocket, session_id, bus)
    except WebSocketDisconnect:
        logger.info("ws disconnected session=%s", session_id)
    except Exception as exc:
        logger.exception("ws error: %s", exc)
        try:
            await websocket.send_json({"type": "error", "error": str(exc)})
        except Exception:
            pass
