"""LiveKit agent — Pipecat LiveKitTransport first, livekit-agents fallback.

Enabled by default (LIVEKIT_WORKER_ENABLED=1). Joins LIVEKIT_DEFAULT_ROOM and
runs full audio duplex via deepiri-speech providers.
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any, Optional

from .settings import settings

logger = logging.getLogger("deepiri-speech.livekit_worker")


@dataclass
class WorkerState:
    enabled: bool = False
    running: bool = False
    backend: str = "none"
    last_error: Optional[str] = None
    rooms_joined: int = 0
    detail: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "running": self.running,
            "backend": self.backend,
            "last_error": self.last_error,
            "rooms_joined": self.rooms_joined,
            "livekit_url": settings.LIVEKIT_URL,
            "default_room": settings.LIVEKIT_DEFAULT_ROOM,
            "agent_identity": settings.LIVEKIT_AGENT_IDENTITY,
            **self.detail,
        }


_state = WorkerState()
_task: Optional[asyncio.Task] = None


def get_worker_state() -> WorkerState:
    return _state


async def _run_pipecat_livekit() -> None:
    from .livekit_rooms import ensure_default_room
    from .pipecat_bridge import is_available, run_livekit_pipecat_pipeline

    if not is_available():
        raise RuntimeError("pipecat-ai not available")

    room_info = await ensure_default_room()
    _state.detail["room"] = room_info
    _state.backend = "pipecat-livekit"
    _state.running = True
    _state.rooms_joined += 1
    logger.info(
        "Starting Pipecat LiveKitTransport room=%s",
        settings.LIVEKIT_DEFAULT_ROOM,
    )
    await run_livekit_pipecat_pipeline(settings.LIVEKIT_DEFAULT_ROOM)


async def _run_agents_worker() -> None:
    from livekit.agents import AutoSubscribe, JobContext, Worker, WorkerOptions
    from livekit import rtc

    from .bus import get_bus
    from .livekit_rooms import ensure_default_room
    from .providers import get_stt, get_tts
    from .vad import get_vad

    await ensure_default_room()
    stt = get_stt()
    tts = get_tts()
    vad = get_vad()

    async def entrypoint(ctx: JobContext) -> None:
        _state.rooms_joined += 1
        await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
        room_name = getattr(ctx.room, "name", "?")
        logger.info("livekit-agents joined room=%s", room_name)
        _state.detail["last_room"] = room_name
        bus = await get_bus()
        await bus.session_started(f"lk-{room_name}", room=room_name)

        @ctx.room.on("track_subscribed")
        def _on_track(track, publication, participant):  # type: ignore[no-untyped-def]
            if getattr(track, "kind", None) != rtc.TrackKind.KIND_AUDIO:
                return

            async def _consume() -> None:
                try:
                    stream = rtc.AudioStream(track)
                    buf = bytearray()
                    async for frame in stream:
                        buf.extend(bytes(frame.data))
                        if len(buf) < 32000:
                            continue
                        chunk = bytes(buf)
                        buf.clear()
                        if not vad.analyze(chunk).has_speech:
                            continue
                        result = await stt.transcribe(chunk, mime_type="audio/pcm")
                        if not result.text.strip():
                            continue
                        logger.info("lk stt room=%s text=%s", room_name, result.text[:120])
                        await bus.stt_final(
                            f"lk-{room_name}", result.text, provider=result.provider
                        )
                        synth = await tts.synthesize(f"I heard: {result.text}")
                        # Publish TTS back when LocalAudioTrack APIs allow
                        _state.detail["last_tts_bytes"] = len(synth.audio)
                except Exception as exc:
                    logger.warning("audio consume error: %s", exc)

            asyncio.create_task(_consume())

        await asyncio.Future()

    opts = WorkerOptions(
        entrypoint_fnc=entrypoint,
        api_key=settings.LIVEKIT_API_KEY,
        api_secret=settings.LIVEKIT_API_SECRET,
        ws_url=settings.LIVEKIT_URL,
    )
    _state.backend = "livekit-agents"
    _state.running = True
    worker = Worker(opts)
    await worker.run()


async def _run_reconnect_loop() -> None:
    """Keep worker alive across disconnects."""
    backoff = 2.0
    while True:
        try:
            try:
                await _run_pipecat_livekit()
            except Exception as pipecat_exc:
                logger.warning(
                    "Pipecat LiveKit path failed (%s); trying livekit-agents",
                    pipecat_exc,
                )
                _state.last_error = str(pipecat_exc)
                await _run_agents_worker()
            backoff = 2.0
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            _state.last_error = str(exc)
            _state.running = False
            logger.exception("LiveKit worker error; retry in %.0fs: %s", backoff, exc)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60.0)


async def start_worker_if_enabled() -> None:
    global _task
    _state.enabled = bool(settings.LIVEKIT_WORKER_ENABLED)
    if not _state.enabled:
        _state.backend = "disabled"
        logger.info("LiveKit worker disabled (LIVEKIT_WORKER_ENABLED=0)")
        return
    if _task and not _task.done():
        return

    async def _runner() -> None:
        try:
            await _run_reconnect_loop()
        except asyncio.CancelledError:
            _state.running = False
            raise
        finally:
            _state.running = False

    _task = asyncio.create_task(_runner(), name="livekit-speech-worker")
    logger.info(
        "LiveKit worker starting (Pipecat LiveKitTransport → agents fallback) room=%s",
        settings.LIVEKIT_DEFAULT_ROOM,
    )


async def stop_worker() -> None:
    global _task
    if _task and not _task.done():
        _task.cancel()
        try:
            await _task
        except asyncio.CancelledError:
            pass
    _task = None
    _state.running = False
