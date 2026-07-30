"""FastAPI entry — deepiri-speech."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from pydantic import BaseModel, Field

from .bus import get_bus
from .livekit_worker import get_worker_state, start_worker_if_enabled, stop_worker
from .providers import get_stt, get_tts
from .settings import settings
from .vad import get_vad

logging.basicConfig(level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO))
logger = logging.getLogger("deepiri-speech")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    bus = await get_bus()
    logger.info(
        "deepiri-speech starting stt=%s tts=%s vad=%s livekit=%s worker=%s",
        settings.STT_PROVIDER,
        settings.TTS_PROVIDER,
        "silero" if settings.ENABLE_SILERO_VAD else "off",
        settings.LIVEKIT_URL,
        settings.LIVEKIT_WORKER_ENABLED,
    )
    await start_worker_if_enabled()
    yield
    await stop_worker()
    await bus.close()


app = FastAPI(
    title="Deepiri Speech",
    version="0.1.0",
    description="Self-hosted STT/TTS voice worker (LiveKit media path)",
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
    return {
        "status": "healthy",
        "service": settings.SERVICE_NAME,
        "stt_provider": settings.STT_PROVIDER,
        "tts_provider": settings.TTS_PROVIDER,
        "vad": getattr(vad, "name", "unknown"),
        "livekit_url": settings.LIVEKIT_PUBLIC_URL,
        "speech_stream": settings.SPEECH_STREAM,
        "worker": worker.to_dict(),
    }


@app.get("/providers")
async def providers():
    vad = get_vad()
    return {
        "stt": settings.STT_PROVIDER,
        "tts": settings.TTS_PROVIDER,
        "stt_model": settings.STT_MODEL,
        "tts_voice": settings.TTS_VOICE,
        "vad": getattr(vad, "name", "unknown"),
        "silero_enabled": settings.ENABLE_SILERO_VAD,
        "worker_enabled": settings.LIVEKIT_WORKER_ENABLED,
    }


@app.get("/v1/worker/status")
async def worker_status():
    return get_worker_state().to_dict()


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
        "livekit_url": settings.LIVEKIT_PUBLIC_URL,
    }


@app.post("/v1/livekit/token")
async def livekit_token(body: LiveKitTokenRequest):
    """Mint a LiveKit access token when livekit-api is installed."""
    try:
        from livekit.api import AccessToken, VideoGrants
    except ImportError:
        return {
            "error": "livekit-api not installed; poetry install -E speech",
            "room_name": body.room_name,
            "identity": body.identity,
            "livekit_url": settings.LIVEKIT_PUBLIC_URL,
            "dev_hint": "Use LiveKit dashboard or install extras for token minting",
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
    """
    Control duplex over WS (typed JSON). Audio media prefers LiveKit tracks;
    this socket is for session control / mock STT of uploaded base64 chunks.
    """
    await websocket.accept()
    session_id = websocket.query_params.get("session_id") or "anon"
    bus = await get_bus()
    await bus.session_started(session_id)
    await websocket.send_json({"type": "session_ready", "session_id": session_id})

    stt = get_stt()
    tts = get_tts()
    try:
        while True:
            msg = await websocket.receive_json()
            mtype = msg.get("type")
            if mtype == "audio_end" or mtype == "stt":
                import base64

                raw = base64.b64decode(msg.get("audio_b64") or "")
                result = await stt.transcribe(raw, mime_type=msg.get("mime_type", "audio/wav"))
                await bus.stt_final(session_id, result.text, provider=result.provider)
                await bus.publish_partial(
                    session_id, {"type": "stt_final", "text": result.text}
                )
                await websocket.send_json(
                    {"type": "stt_final", "text": result.text, "provider": result.provider}
                )
            elif mtype == "speak":
                text = msg.get("text") or ""
                result = await tts.synthesize(text, voice=msg.get("voice"))
                import base64

                await websocket.send_json(
                    {
                        "type": "tts_chunk",
                        "audio_b64": base64.b64encode(result.audio).decode("ascii"),
                        "mime_type": result.mime_type,
                        "is_final": True,
                    }
                )
            elif mtype == "ping":
                await websocket.send_json({"type": "pong"})
            elif mtype == "close":
                break
    except WebSocketDisconnect:
        logger.info("ws disconnected session=%s", session_id)
    except Exception as exc:
        logger.exception("ws error: %s", exc)
        try:
            await websocket.send_json({"type": "error", "error": str(exc)})
        except Exception:
            pass
