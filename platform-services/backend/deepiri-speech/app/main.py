"""FastAPI entry — deepiri-speech.

Pipecat + LiveKit always-on (in-process). WS JSON duplex + Pipecat media WS +
LiveKit WebRTC rooms with agent worker.
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
from .livekit_rooms import create_room, delete_room, ensure_default_room, list_rooms, mint_token
from .livekit_worker import get_worker_state, start_worker_if_enabled, stop_worker
from .pipecat_bridge import is_available as pipecat_available
from .pipecat_bridge import run_fastapi_pipecat_pipeline
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
        "deepiri-speech starting stt=%s tts=%s device=%s pipecat=%s livekit_worker=%s",
        settings.STT_PROVIDER,
        settings.TTS_PROVIDER,
        device.kind,
        pipecat_available(),
        settings.LIVEKIT_WORKER_ENABLED,
    )
    try:
        room = await ensure_default_room()
        logger.info("LiveKit default room: %s", room)
    except Exception as exc:
        logger.warning("LiveKit room ensure skipped: %s", exc)
    await start_worker_if_enabled()
    yield
    await stop_worker()
    await bus.close()


app = FastAPI(
    title="Deepiri Speech",
    version="0.3.0",
    description=(
        "Poetry FastAPI speech worker — Pipecat (always-on) + LiveKit WebRTC "
        "(rooms/agent) over deepiri providers"
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
    room_name: Optional[str] = None
    identity: str
    name: Optional[str] = None
    agent: bool = False
    room_admin: bool = False


class LiveKitRoomCreate(BaseModel):
    name: Optional[str] = None
    empty_timeout: Optional[int] = None
    max_participants: Optional[int] = None


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
        "pipecat": pipecat_status(),
        "transport": "websocket+livekit",
        "livekit": {
            "url": settings.LIVEKIT_PUBLIC_URL,
            "worker_enabled": settings.LIVEKIT_WORKER_ENABLED,
            "default_room": settings.LIVEKIT_DEFAULT_ROOM,
            "worker": worker.to_dict(),
        },
        "speech_stream": settings.SPEECH_STREAM,
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
        "pipecat": pipecat_status(),
        "worker_enabled": settings.LIVEKIT_WORKER_ENABLED,
        "device": device.to_dict(),
        "engines": {
            "stt_default": "faster_whisper",
            "stt_apple_edge": "whisper_cpp",
            "tts_default": "kokoro",
            "tts_avoid": "xtts_v2 (CPML)",
            "orchestration": "pipecat (auto)",
            "webrtc": "livekit",
        },
    }


@app.get("/v1/worker/status")
async def worker_status():
    return get_worker_state().to_dict()


@app.get("/v1/pipeline/status")
async def pipeline_status():
    return {
        "pipecat": pipecat_status(),
        "endpoints": {
            "json_ws": "/v1/session/ws",
            "pipecat_ws": "/v1/pipecat/ws",
            "livekit_token": "/v1/livekit/token",
            "livekit_rooms": "/v1/livekit/rooms",
        },
        "livekit_worker": get_worker_state().to_dict(),
        "note": (
            "Pipecat is always-on in-process. LiveKit is the WebRTC SFU; "
            "the agent joins via Pipecat LiveKitTransport (agents fallback)."
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
    room = body.room_name or settings.LIVEKIT_DEFAULT_ROOM
    bus = await get_bus()
    await bus.session_started(session_id, user_id=body.user_id, room=room)
    user_token = None
    try:
        user_token = mint_token(
            room_name=room,
            identity=body.user_id or f"user-{session_id[:8]}",
            name=body.user_id,
        )
    except Exception as exc:
        logger.debug("token mint skipped: %s", exc)
    return {
        "session_id": session_id,
        "room_name": room,
        "ws_url": f"ws://localhost:{settings.PORT}/v1/session/ws?session_id={session_id}",
        "pipecat_ws_url": f"ws://localhost:{settings.PORT}/v1/pipecat/ws?session_id={session_id}",
        "transport": "websocket+livekit",
        "livekit_url": settings.LIVEKIT_PUBLIC_URL,
        "livekit_token": user_token,
    }


@app.get("/v1/livekit/rooms")
async def livekit_rooms_list():
    try:
        return {"rooms": await list_rooms(), "url": settings.LIVEKIT_PUBLIC_URL}
    except Exception as exc:
        return {"rooms": [], "error": str(exc), "url": settings.LIVEKIT_PUBLIC_URL}


@app.post("/v1/livekit/rooms")
async def livekit_rooms_create(body: LiveKitRoomCreate):
    return await create_room(
        body.name,
        empty_timeout=body.empty_timeout,
        max_participants=body.max_participants,
    )


@app.delete("/v1/livekit/rooms/{name}")
async def livekit_rooms_delete(name: str):
    return await delete_room(name)


@app.post("/v1/livekit/token")
async def livekit_token(body: LiveKitTokenRequest):
    """Mint a full-capability LiveKit access token for rooms/phone."""
    room = body.room_name or settings.LIVEKIT_DEFAULT_ROOM
    try:
        token = mint_token(
            room_name=room,
            identity=body.identity,
            name=body.name,
            agent=body.agent,
            room_admin=body.room_admin or body.agent,
            can_publish=True,
            can_subscribe=True,
            room_create=True,
        )
    except Exception as exc:
        return {
            "error": str(exc),
            "room_name": room,
            "identity": body.identity,
            "livekit_url": settings.LIVEKIT_PUBLIC_URL,
        }
    return {
        "token": token,
        "url": settings.LIVEKIT_PUBLIC_URL,
        "room_name": room,
        "identity": body.identity,
        "agent": body.agent,
        "grants": [
            "room_join",
            "can_publish",
            "can_subscribe",
            "can_publish_data",
            "can_update_own_metadata",
            "room_create",
        ],
    }


@app.websocket("/v1/session/ws")
async def duplex_ws(websocket: WebSocket):
    """JSON duplex (default). Pass protocol=pipecat for FastAPIWebsocketTransport."""
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


@app.websocket("/v1/pipecat/ws")
async def pipecat_media_ws(websocket: WebSocket):
    """Full Pipecat FastAPIWebsocketTransport media duplex."""
    await websocket.accept()
    session_id = websocket.query_params.get("session_id") or "pipecat"
    bus = await get_bus()
    await bus.session_started(session_id, transport="pipecat-ws")
    if not pipecat_available():
        await websocket.send_json(
            {"type": "error", "error": "pipecat-ai not installed (should be a core dep)"}
        )
        await websocket.close()
        return
    try:
        await run_fastapi_pipecat_pipeline(websocket)
    except WebSocketDisconnect:
        logger.info("pipecat ws disconnected session=%s", session_id)
    except Exception as exc:
        logger.exception("pipecat ws error: %s", exc)
