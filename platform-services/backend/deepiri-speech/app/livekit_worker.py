"""LiveKit agent worker — optional background task for real audio tracks.

Enable with LIVEKIT_WORKER_ENABLED=1. Requires poetry extras `speech`
(livekit-api / livekit-agents when available).

Until livekit-agents is installed, runs a healthy stub so the API container
stays up and /v1/worker/status reports readiness.
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
            **self.detail,
        }


_state = WorkerState()
_task: Optional[asyncio.Task] = None


def get_worker_state() -> WorkerState:
    return _state


async def _run_agents_worker() -> None:
    """Start livekit-agents Worker when the package is present."""
    try:
        from livekit.agents import AutoSubscribe, JobContext, Worker, WorkerOptions
        from livekit import rtc  # noqa: F401
    except ImportError as exc:
        raise RuntimeError(f"livekit-agents not installed: {exc}") from exc

    from .providers import get_stt
    from .vad import get_vad

    async def entrypoint(ctx: JobContext) -> None:
        _state.rooms_joined += 1
        await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
        logger.info("LiveKit worker joined room=%s", getattr(ctx.room, "name", "?"))
        stt = get_stt()
        vad = get_vad()
        _state.detail["last_room"] = getattr(ctx.room, "name", None)

        # Track subscription is framework-version specific; keep job alive and
        # process frames when AudioStream is available on subscribed tracks.
        try:
            from livekit import rtc

            @ctx.room.on("track_subscribed")
            def _on_track(track, publication, participant):  # type: ignore[no-untyped-def]
                if getattr(track, "kind", None) != getattr(rtc.TrackKind, "KIND_AUDIO", None):
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
                            if result.text.strip():
                                logger.info("stt room=%s text=%s", ctx.room.name, result.text[:120])
                    except Exception as exc:
                        logger.warning("audio consume error: %s", exc)

                asyncio.create_task(_consume())
        except Exception as exc:
            logger.warning("track wiring limited: %s", exc)

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


async def _run_stub() -> None:
    _state.backend = "stub"
    _state.running = True
    _state.detail = {
        "hint": (
            "Install extras (SPEECH_EXTRAS=1) including livekit-agents, "
            "then set LIVEKIT_WORKER_ENABLED=1 for real audio tracks."
        ),
    }
    logger.info("LiveKit worker stub active (media path not subscribed yet)")
    while True:
        await asyncio.sleep(3600)


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
            await _run_agents_worker()
        except Exception as exc:
            _state.last_error = str(exc)
            logger.warning("agents worker unavailable (%s); using stub", exc)
            try:
                await _run_stub()
            except asyncio.CancelledError:
                _state.running = False
                raise
        finally:
            _state.running = False

    _task = asyncio.create_task(_runner(), name="livekit-speech-worker")


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
