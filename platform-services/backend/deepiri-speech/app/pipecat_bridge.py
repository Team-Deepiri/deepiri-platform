"""Pipecat in-process runtime — full Pipeline over our providers.

Always enabled when pipecat-ai is installed (default dependency).
Transports:
  - FastAPI WebSocket  → /v1/session/ws and /v1/pipecat/ws
  - LiveKit WebRTC     → background agent via LiveKitTransport
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any, Optional

from fastapi import WebSocket

from .providers import get_stt, get_tts
from .settings import settings
from .vad import get_vad

logger = logging.getLogger("deepiri-speech.pipecat")


def is_available() -> bool:
    if not settings.PIPECAT_ENABLED:
        return False
    try:
        import pipecat  # noqa: F401

        return True
    except ImportError:
        return False


def status_dict() -> dict[str, Any]:
    ver = None
    livekit_transport = False
    fastapi_transport = False
    if is_available():
        try:
            import pipecat

            ver = getattr(pipecat, "__version__", "installed")
        except ImportError:
            pass
        try:
            from pipecat.transports.livekit.transport import LiveKitTransport  # noqa: F401

            livekit_transport = True
        except ImportError:
            pass
        try:
            from pipecat.transports.websocket.fastapi import (  # noqa: F401
                FastAPIWebsocketTransport,
            )

            fastapi_transport = True
        except ImportError:
            try:
                from pipecat.transports.network.fastapi_websocket import (  # noqa: F401
                    FastAPIWebsocketTransport,
                )

                fastapi_transport = True
            except ImportError:
                pass
    return {
        "enabled": settings.PIPECAT_ENABLED,
        "available": is_available(),
        "version": ver,
        "in_process": True,
        "separate_service": False,
        "auto_enabled": True,
        "transports": {
            "fastapi_websocket": fastapi_transport,
            "livekit": livekit_transport,
        },
        "endpoint_ws": "/v1/session/ws",
        "endpoint_pipecat_ws": "/v1/pipecat/ws",
    }


def _import_fastapi_ws():
    try:
        from pipecat.transports.websocket.fastapi import (
            FastAPIWebsocketParams,
            FastAPIWebsocketTransport,
        )

        return FastAPIWebsocketTransport, FastAPIWebsocketParams
    except ImportError:
        from pipecat.transports.network.fastapi_websocket import (
            FastAPIWebsocketParams,
            FastAPIWebsocketTransport,
        )

        return FastAPIWebsocketTransport, FastAPIWebsocketParams


def _build_provider_processors():
    """STT/TTS/VAD as Pipecat FrameProcessors wrapping deepiri-speech providers."""
    from pipecat.frames.frames import (
        AudioRawFrame,
        EndFrame,
        Frame,
        TextFrame,
        TranscriptionFrame,
    )
    from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

    stt = get_stt()
    tts = get_tts()
    vad = get_vad()

    class ProviderSTT(FrameProcessor):
        def __init__(self):
            super().__init__()
            self._buf = bytearray()

        async def process_frame(self, frame: Frame, direction: FrameDirection):
            await super().process_frame(frame, direction)
            name = frame.__class__.__name__
            if isinstance(frame, AudioRawFrame) or hasattr(frame, "audio"):
                chunk = getattr(frame, "audio", b"")
                if isinstance(chunk, (bytes, bytearray)):
                    self._buf.extend(chunk)
                # Continuous chunking ~1s @ 16k mono int16
                if len(self._buf) >= 32000:
                    audio = bytes(self._buf)
                    self._buf.clear()
                    if settings.VAD_SKIP_EMPTY and not vad.analyze(audio).has_speech:
                        return
                    result = await stt.transcribe(audio, mime_type="audio/pcm")
                    if result.text.strip():
                        await self.push_frame(
                            TranscriptionFrame(result.text, "", ""),
                            direction,
                        )
                return
            if name in ("UserStoppedSpeakingFrame", "EndFrame") and self._buf:
                audio = bytes(self._buf)
                self._buf.clear()
                result = await stt.transcribe(audio, mime_type="audio/pcm")
                if result.text.strip():
                    await self.push_frame(
                        TranscriptionFrame(result.text, "", ""),
                        direction,
                    )
                if name == "EndFrame":
                    await self.push_frame(frame, direction)
                return
            await self.push_frame(frame, direction)

    class CyrexOrEchoLLM(FrameProcessor):
        """Turn transcriptions into speakable reply text via Cyrex or echo."""

        async def process_frame(self, frame: Frame, direction: FrameDirection):
            await super().process_frame(frame, direction)
            if isinstance(frame, TranscriptionFrame) and getattr(frame, "text", None):
                if settings.PIPECAT_AUTO_REPLY:
                    reply = await self._reply(frame.text)
                    await self.push_frame(TextFrame(reply), direction)
                else:
                    await self.push_frame(TextFrame(frame.text), direction)
                return
            await self.push_frame(frame, direction)

        async def _reply(self, user_text: str) -> str:
            try:
                import httpx

                async with httpx.AsyncClient(timeout=20.0) as client:
                    r = await client.post(
                        f"{settings.CYREX_URL.rstrip('/')}/v1/chat/completions",
                        headers={"Authorization": f"Bearer {settings.CYREX_API_KEY}"},
                        json={
                            "model": "default",
                            "messages": [{"role": "user", "content": user_text}],
                        },
                    )
                    if r.status_code < 300:
                        data = r.json()
                        choices = data.get("choices") or []
                        if choices:
                            return (
                                choices[0].get("message", {}).get("content")
                                or choices[0].get("text")
                                or user_text
                            )
            except Exception as exc:
                logger.debug("cyrex LLM skip: %s", exc)
            return f"I heard: {user_text}"

    class ProviderTTS(FrameProcessor):
        async def process_frame(self, frame: Frame, direction: FrameDirection):
            await super().process_frame(frame, direction)
            if isinstance(frame, TextFrame) and getattr(frame, "text", None):
                synth = await tts.synthesize(frame.text)
                await self.push_frame(
                    AudioRawFrame(audio=synth.audio, sample_rate=24000, num_channels=1),
                    direction,
                )
                return
            await self.push_frame(frame, direction)

    return ProviderSTT(), CyrexOrEchoLLM(), ProviderTTS()


async def run_fastapi_pipecat_pipeline(websocket: WebSocket) -> None:
    """Full Pipecat Pipeline on FastAPI WebSocket (audio duplex)."""
    from pipecat.pipeline.pipeline import Pipeline
    from pipecat.pipeline.runner import PipelineRunner
    from pipecat.pipeline.task import PipelineParams, PipelineTask

    Transport, Params = _import_fastapi_ws()

    serializer = None
    try:
        from pipecat.serializers.protobuf import ProtobufFrameSerializer

        serializer = ProtobufFrameSerializer()
    except Exception:
        try:
            from pipecat.serializers.audio_raw import AudioRawFrameSerializer

            serializer = AudioRawFrameSerializer()
        except Exception:
            serializer = None

    params_kwargs: dict[str, Any] = {
        "audio_in_enabled": True,
        "audio_out_enabled": True,
        "add_wav_header": False,
    }
    if serializer is not None:
        params_kwargs["serializer"] = serializer

    transport = Transport(websocket=websocket, params=Params(**params_kwargs))
    stt_proc, llm_proc, tts_proc = _build_provider_processors()

    pipeline = Pipeline(
        [
            transport.input(),
            stt_proc,
            llm_proc,
            tts_proc,
            transport.output(),
        ]
    )
    task = PipelineTask(
        pipeline,
        params=PipelineParams(
            allow_interruptions=True,
            enable_metrics=True,
        ),
    )

    @transport.event_handler("on_client_disconnected")
    async def _on_disc(_transport, _ws):
        await task.cancel()

    runner = PipelineRunner(handle_sigint=False)
    await runner.run(task)


async def run_livekit_pipecat_pipeline(room_name: Optional[str] = None) -> None:
    """Full Pipecat Pipeline on LiveKitTransport (WebRTC rooms)."""
    from pipecat.pipeline.pipeline import Pipeline
    from pipecat.pipeline.runner import PipelineRunner
    from pipecat.pipeline.task import PipelineParams, PipelineTask
    from pipecat.transports.livekit.transport import LiveKitParams, LiveKitTransport

    from .livekit_rooms import mint_token

    room = room_name or settings.LIVEKIT_DEFAULT_ROOM
    token = mint_token(
        room_name=room,
        identity=settings.LIVEKIT_AGENT_IDENTITY,
        name="Deepiri Speech Agent",
        agent=True,
        room_admin=True,
        can_publish=True,
        can_subscribe=True,
    )

    transport = LiveKitTransport(
        url=settings.LIVEKIT_URL,
        token=token,
        room_name=room,
        params=LiveKitParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
        ),
    )
    stt_proc, llm_proc, tts_proc = _build_provider_processors()
    pipeline = Pipeline(
        [
            transport.input(),
            stt_proc,
            llm_proc,
            tts_proc,
            transport.output(),
        ]
    )
    task = PipelineTask(
        pipeline,
        params=PipelineParams(allow_interruptions=True, enable_metrics=True),
    )

    @transport.event_handler("on_connected")
    async def _on_conn(_t):
        logger.info("Pipecat LiveKitTransport connected room=%s", room)

    @transport.event_handler("on_disconnected")
    async def _on_disc(_t):
        logger.info("Pipecat LiveKitTransport disconnected room=%s", room)
        await task.cancel()

    runner = PipelineRunner(handle_sigint=False)
    await runner.run(task)


# Back-compat aliases used by older modules
async def process_turn_with_pipecat(audio: bytes, **kwargs):
    from .contracts import TranscriptSegment
    from .providers import get_stt
    from .vad import get_vad

    stt = get_stt()
    vad = get_vad()
    meta = {"orchestrator": "pipecat", "vad": getattr(vad, "name", "?"), "mode": "oneshot"}
    if settings.VAD_SKIP_EMPTY and not vad.analyze(audio).has_speech:
        meta["skipped"] = "no_speech"
        return (
            TranscriptSegment(text="", is_final=True, provider=stt.name, model="skipped"),
            None,
            meta,
        )
    seg = await stt.transcribe(
        audio,
        mime_type=kwargs.get("mime_type", "audio/wav"),
        language=kwargs.get("language"),
    )
    return seg, None, meta


def note_pipecat_ready(session_id: str) -> None:
    logger.info("Pipecat ready session=%s status=%s", session_id, status_dict())


def build_provider_services() -> dict[str, Any]:
    stt, llm, tts = _build_provider_processors()
    return {
        "stt": type(stt),
        "llm": type(llm),
        "tts": type(tts),
        "status": status_dict(),
    }
