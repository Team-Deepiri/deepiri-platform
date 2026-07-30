"""Optional in-process Pipecat adapters over deepiri-speech providers.

Not a separate service. Install: poetry install -E pipecat (or -E speech)
Enable: PIPECAT_ENABLED=1

Transport remains FastAPI WebSocket `/v1/session/ws` — not a second SFU.
LiveKit stays optional for real WebRTC rooms/phone only.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from .contracts import SynthesisResult, TranscriptSegment
from .providers import get_stt, get_tts
from .settings import settings
from .vad import get_vad

logger = logging.getLogger("deepiri-speech.pipecat")

_sessions_noted: set[str] = set()


def is_available() -> bool:
    if not settings.PIPECAT_ENABLED:
        return False
    try:
        import pipecat  # noqa: F401

        return True
    except ImportError:
        return False


def note_pipecat_ready(session_id: str) -> None:
    if session_id in _sessions_noted:
        return
    _sessions_noted.add(session_id)
    try:
        import pipecat

        logger.info(
            "Pipecat %s in-process — providers drive WS pipeline (session=%s)",
            getattr(pipecat, "__version__", "?"),
            session_id,
        )
    except ImportError:
        pass


async def process_turn_with_pipecat(
    audio: bytes,
    *,
    mime_type: str = "audio/wav",
    language: Optional[str] = None,
) -> tuple[TranscriptSegment, Optional[SynthesisResult], dict[str, Any]]:
    """
    One VAD→STT turn using Pipecat FrameProcessors wrapping our providers.

    Falls back to direct provider calls if frame APIs differ across pipecat versions.
    """
    stt = get_stt()
    tts = get_tts()
    vad = get_vad()
    meta: dict[str, Any] = {
        "orchestrator": "pipecat",
        "vad": getattr(vad, "name", "unknown"),
    }

    vad_result = vad.analyze(audio)
    if not vad_result.has_speech and settings.VAD_SKIP_EMPTY:
        empty = TranscriptSegment(
            text="",
            is_final=True,
            language=language or "en",
            provider=getattr(stt, "name", "unknown"),
            model="skipped",
        )
        meta["skipped"] = "no_speech"
        return empty, None, meta

    # Prefer Pipecat processor path when FrameProcessor API is present
    try:
        from pipecat.frames.frames import AudioRawFrame, TextFrame, TranscriptionFrame
        from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

        class _STT(FrameProcessor):
            def __init__(self):
                super().__init__()
                self.result: Optional[TranscriptSegment] = None

            async def process_frame(self, frame, direction: FrameDirection):
                await super().process_frame(frame, direction)
                if isinstance(frame, AudioRawFrame) or frame.__class__.__name__ in (
                    "InputAudioRawFrame",
                    "AudioRawFrame",
                ):
                    raw = getattr(frame, "audio", None) or audio
                    self.result = await stt.transcribe(
                        raw if isinstance(raw, (bytes, bytearray)) else audio,
                        mime_type=mime_type,
                        language=language,
                    )
                    await self.push_frame(
                        TranscriptionFrame(
                            self.result.text,
                            user_id="",
                            timestamp="",
                        ),
                        direction,
                    )
                    return
                await self.push_frame(frame, direction)

        proc = _STT()
        # Drive a single frame through the processor
        frame = AudioRawFrame(audio=audio, sample_rate=16000, num_channels=1)
        await proc.process_frame(frame, FrameDirection.DOWNSTREAM)
        segment = proc.result or await stt.transcribe(
            audio, mime_type=mime_type, language=language
        )
        meta["pipecat_processors"] = True
        return segment, None, meta
    except Exception as exc:
        logger.debug("Pipecat frame path fallback to providers: %s", exc)
        segment = await stt.transcribe(audio, mime_type=mime_type, language=language)
        meta["pipecat_processors"] = False
        meta["fallback"] = str(exc)
        return segment, None, meta


def build_provider_services() -> dict[str, Any]:
    """Expose processor factories for advanced / future Pipeline wiring."""
    if not is_available():
        raise RuntimeError("pipecat-ai not installed or PIPECAT_ENABLED=0")

    from pipecat.frames.frames import AudioRawFrame, Frame, TextFrame, TranscriptionFrame
    from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

    class ProviderSTTProcessor(FrameProcessor):
        def __init__(self):
            super().__init__()
            self._stt = get_stt()
            self._buf = bytearray()

        async def process_frame(self, frame: Frame, direction: FrameDirection):
            await super().process_frame(frame, direction)
            if isinstance(frame, AudioRawFrame) or hasattr(frame, "audio"):
                chunk = getattr(frame, "audio", b"")
                if isinstance(chunk, (bytes, bytearray)):
                    self._buf.extend(chunk)
            if frame.__class__.__name__ in (
                "EndFrame",
                "UserStoppedSpeakingFrame",
                "TranscriptionFrame",
            ):
                if self._buf:
                    result = await self._stt.transcribe(bytes(self._buf), mime_type="audio/pcm")
                    self._buf.clear()
                    await self.push_frame(
                        TranscriptionFrame(result.text, "", ""),
                        direction,
                    )
                    return
            await self.push_frame(frame, direction)

    class ProviderTTSProcessor(FrameProcessor):
        def __init__(self):
            super().__init__()
            self._tts = get_tts()

        async def process_frame(self, frame: Frame, direction: FrameDirection):
            await super().process_frame(frame, direction)
            text = getattr(frame, "text", None) if isinstance(frame, TextFrame) else None
            if text:
                synth = await self._tts.synthesize(text)
                await self.push_frame(
                    AudioRawFrame(audio=synth.audio, sample_rate=24000, num_channels=1),
                    direction,
                )
                return
            await self.push_frame(frame, direction)

    return {
        "stt": ProviderSTTProcessor,
        "tts": ProviderTTSProcessor,
        "vad_name": getattr(get_vad(), "name", "passthrough"),
        "transport": "fastapi-websocket",
        "service": "deepiri-speech (in-process)",
    }


def status_dict() -> dict[str, Any]:
    ver = None
    if is_available():
        try:
            import pipecat

            ver = getattr(pipecat, "__version__", "installed")
        except ImportError:
            ver = None
    return {
        "enabled": settings.PIPECAT_ENABLED,
        "available": is_available(),
        "version": ver,
        "in_process": True,
        "separate_service": False,
        "transport": "websocket",
        "endpoint": "/v1/session/ws",
    }
