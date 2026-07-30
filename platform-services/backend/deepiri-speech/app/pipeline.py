"""Voice pipeline on deepiri-speech providers — WS transport primary.

Pipecat is an optional in-process orchestrator (not a separate service).
Without it, the same VAD→STT→TTS path runs natively on all OS.
LiveKit is NOT used here.
"""
from __future__ import annotations

import base64
import logging
from dataclasses import dataclass, field
from typing import Any, Optional

from fastapi import WebSocket

from .bus import SpeechBus
from .pipecat_bridge import is_available as pipecat_available
from .pipecat_bridge import note_pipecat_ready, process_turn_with_pipecat, status_dict
from .providers import get_stt, get_tts
from .settings import settings
from .vad import get_vad

logger = logging.getLogger("deepiri-speech.pipeline")


@dataclass
class PipelineTurn:
    transcript: str = ""
    stt_provider: str = ""
    tts_audio_b64: Optional[str] = None
    tts_mime: Optional[str] = None
    tts_provider: str = ""
    vad_provider: str = ""
    reply_text: Optional[str] = None
    orchestrator: str = "native"
    meta: dict[str, Any] = field(default_factory=dict)


class VoicePipeline:
    """Provider-backed voice agent pipeline (native or Pipecat-orchestrated)."""

    def __init__(self, session_id: str, bus: Optional[SpeechBus] = None):
        self.session_id = session_id
        self.bus = bus
        self.stt = get_stt()
        self.tts = get_tts()
        self.vad = get_vad()

    async def process_audio(
        self,
        audio: bytes,
        *,
        mime_type: str = "audio/wav",
        language: Optional[str] = None,
        auto_reply: bool = False,
        speak_transcript: bool = False,
    ) -> PipelineTurn:
        turn = PipelineTurn(vad_provider=getattr(self.vad, "name", "unknown"))

        if pipecat_available():
            segment, _, meta = await process_turn_with_pipecat(
                audio, mime_type=mime_type, language=language
            )
            turn.orchestrator = "pipecat"
            turn.meta = meta
            turn.vad_provider = meta.get("vad", turn.vad_provider)
            turn.transcript = segment.text
            turn.stt_provider = segment.provider
            if meta.get("skipped") == "no_speech":
                return turn
        else:
            turn.orchestrator = "native"
            vad_result = self.vad.analyze(audio)
            if not vad_result.has_speech and settings.VAD_SKIP_EMPTY:
                turn.meta["skipped"] = "no_speech"
                return turn
            result = await self.stt.transcribe(
                audio, mime_type=mime_type, language=language
            )
            turn.transcript = result.text
            turn.stt_provider = result.provider

        if self.bus and turn.transcript:
            await self.bus.stt_final(
                self.session_id,
                turn.transcript,
                provider=turn.stt_provider,
            )
            await self.bus.publish_partial(
                self.session_id, {"type": "stt_final", "text": turn.transcript}
            )

        speak_text: Optional[str] = None
        if auto_reply and turn.transcript.strip():
            speak_text = await self._cyrex_reply(turn.transcript)
            turn.reply_text = speak_text
        elif speak_transcript and turn.transcript.strip():
            speak_text = turn.transcript

        if speak_text:
            synth = await self.tts.synthesize(speak_text)
            turn.tts_audio_b64 = base64.b64encode(synth.audio).decode("ascii")
            turn.tts_mime = synth.mime_type
            turn.tts_provider = synth.provider

        return turn

    async def speak(self, text: str, *, voice: Optional[str] = None) -> PipelineTurn:
        synth = await self.tts.synthesize(text, voice=voice)
        return PipelineTurn(
            tts_audio_b64=base64.b64encode(synth.audio).decode("ascii"),
            tts_mime=synth.mime_type,
            tts_provider=synth.provider,
            reply_text=text,
            orchestrator="pipecat" if pipecat_available() else "native",
        )

    async def _cyrex_reply(self, user_text: str) -> str:
        try:
            import httpx

            async with httpx.AsyncClient(timeout=30.0) as client:
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
            logger.debug("cyrex reply skipped: %s", exc)
        return f"I heard: {user_text}"


async def run_ws_session(websocket: WebSocket, session_id: str, bus: SpeechBus) -> None:
    """Primary duplex transport: FastAPI WebSocket JSON protocol."""
    pipeline = VoicePipeline(session_id, bus=bus)
    ready = {
        "type": "session_ready",
        "session_id": session_id,
        "transport": "websocket",
        "pipeline": "pipecat" if pipecat_available() else "native",
        "pipecat": status_dict(),
        "stt": getattr(pipeline.stt, "name", settings.STT_PROVIDER),
        "tts": getattr(pipeline.tts, "name", settings.TTS_PROVIDER),
        "vad": getattr(pipeline.vad, "name", "passthrough"),
    }
    await websocket.send_json(ready)

    if pipecat_available():
        note_pipecat_ready(session_id)

    while True:
        msg = await websocket.receive_json()
        mtype = msg.get("type")
        if mtype in ("audio_end", "stt"):
            raw = base64.b64decode(msg.get("audio_b64") or "")
            turn = await pipeline.process_audio(
                raw,
                mime_type=msg.get("mime_type", "audio/wav"),
                language=msg.get("language"),
                auto_reply=bool(msg.get("auto_reply")),
                speak_transcript=bool(msg.get("speak_transcript")),
            )
            await websocket.send_json(
                {
                    "type": "stt_final",
                    "text": turn.transcript,
                    "provider": turn.stt_provider,
                    "vad": turn.vad_provider,
                    "orchestrator": turn.orchestrator,
                    "meta": turn.meta,
                }
            )
            if turn.tts_audio_b64:
                await websocket.send_json(
                    {
                        "type": "tts_chunk",
                        "audio_b64": turn.tts_audio_b64,
                        "mime_type": turn.tts_mime,
                        "is_final": True,
                        "provider": turn.tts_provider,
                        "text": turn.reply_text,
                    }
                )
        elif mtype == "speak":
            turn = await pipeline.speak(msg.get("text") or "", voice=msg.get("voice"))
            await websocket.send_json(
                {
                    "type": "tts_chunk",
                    "audio_b64": turn.tts_audio_b64,
                    "mime_type": turn.tts_mime,
                    "is_final": True,
                    "provider": turn.tts_provider,
                }
            )
        elif mtype == "ping":
            await websocket.send_json({"type": "pong"})
        elif mtype == "close":
            break
        else:
            await websocket.send_json({"type": "error", "error": f"unknown type: {mtype}"})
