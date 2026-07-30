"""STT/TTS providers — mock by default; faster-whisper / OpenAI optional."""
from __future__ import annotations

import asyncio
import io
import logging
from typing import Optional

from .contracts import SynthesisResult, TranscriptSegment
from .settings import settings
from .vad import get_vad

logger = logging.getLogger("deepiri-speech.providers")


class MockSTT:
    name = "mock"

    async def transcribe(
        self, audio: bytes, *, mime_type: str = "audio/wav", language: Optional[str] = None
    ) -> TranscriptSegment:
        return TranscriptSegment(
            text=f"[mock transcript: {len(audio)} bytes]",
            is_final=True,
            confidence=1.0,
            language=language or "en",
            provider=self.name,
            model="mock",
        )


class MockTTS:
    name = "mock"

    async def synthesize(self, text: str, *, voice: Optional[str] = None) -> SynthesisResult:
        return SynthesisResult(
            audio=f"MOCK_TTS:{text}".encode("utf-8"),
            mime_type="audio/mock",
            provider=self.name,
            model="mock",
            voice=voice or settings.TTS_VOICE,
        )


class OpenAISTT:
    name = "openai"

    def __init__(self, api_key: str, model: str = "whisper-1"):
        self.api_key = api_key
        self.model = model

    async def transcribe(
        self, audio: bytes, *, mime_type: str = "audio/wav", language: Optional[str] = None
    ) -> TranscriptSegment:
        from openai import OpenAI

        client = OpenAI(api_key=self.api_key)

        def _run():
            bio = io.BytesIO(audio)
            bio.name = "audio.wav"
            kwargs = {"model": self.model, "file": bio}
            if language:
                kwargs["language"] = language
            return client.audio.transcriptions.create(**kwargs)

        result = await asyncio.to_thread(_run)
        text = getattr(result, "text", None) or str(result)
        return TranscriptSegment(
            text=text.strip(),
            is_final=True,
            language=language,
            provider=self.name,
            model=self.model,
        )


class OpenAITTS:
    name = "openai"

    def __init__(self, api_key: str, model: str = "tts-1", voice: str = "alloy"):
        self.api_key = api_key
        self.model = model
        self.voice = voice

    async def synthesize(self, text: str, *, voice: Optional[str] = None) -> SynthesisResult:
        from openai import OpenAI

        client = OpenAI(api_key=self.api_key)
        v = voice or self.voice

        def _run() -> bytes:
            resp = client.audio.speech.create(
                model=self.model, voice=v, input=text, response_format="mp3"
            )
            return resp.content

        audio = await asyncio.to_thread(_run)
        return SynthesisResult(
            audio=audio,
            mime_type="audio/mpeg",
            provider=self.name,
            model=self.model,
            voice=v,
        )


class FasterWhisperSTT:
    name = "faster_whisper"

    def __init__(self, model_size: str = "small.en"):
        self.model_size = model_size
        self._model = None

    def _load(self):
        if self._model is not None:
            return self._model
        from faster_whisper import WhisperModel

        device = "cpu"
        compute = "int8"
        try:
            import torch

            if torch.cuda.is_available():
                device = "cuda"
                compute = "float16"
        except Exception:
            pass
        self._model = WhisperModel(self.model_size, device=device, compute_type=compute)
        return self._model

    async def transcribe(
        self, audio: bytes, *, mime_type: str = "audio/wav", language: Optional[str] = None
    ) -> TranscriptSegment:
        import os
        import tempfile

        if settings.VAD_SKIP_EMPTY:
            vad = get_vad().analyze(audio)
            if not vad.has_speech:
                return TranscriptSegment(
                    text="",
                    is_final=True,
                    language=language or "en",
                    confidence=0.0,
                    provider=self.name,
                    model=self.model_size,
                )

        def _run() -> TranscriptSegment:
            model = self._load()
            suffix = ".wav" if "wav" in (mime_type or "") else ".webm"
            with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
                tmp.write(audio)
                path = tmp.name
            try:
                segments, info = model.transcribe(path, language=language)
                text = " ".join(s.text.strip() for s in segments if s.text).strip()
                return TranscriptSegment(
                    text=text,
                    is_final=True,
                    language=getattr(info, "language", language),
                    confidence=getattr(info, "language_probability", None),
                    provider=self.name,
                    model=self.model_size,
                )
            finally:
                try:
                    os.unlink(path)
                except OSError:
                    pass

        return await asyncio.to_thread(_run)


_stt_singleton = None
_tts_singleton = None


def get_stt():
    global _stt_singleton
    if _stt_singleton is not None:
        return _stt_singleton
    provider = (settings.STT_PROVIDER or "mock").strip().lower()
    if provider == "openai" and settings.OPENAI_API_KEY:
        _stt_singleton = OpenAISTT(settings.OPENAI_API_KEY)
        return _stt_singleton
    if provider == "faster_whisper":
        try:
            import faster_whisper  # noqa: F401

            _stt_singleton = FasterWhisperSTT(settings.STT_MODEL)
            return _stt_singleton
        except ImportError:
            logger.warning("faster-whisper not installed; falling back to mock")
    _stt_singleton = MockSTT()
    return _stt_singleton


def get_tts():
    global _tts_singleton
    if _tts_singleton is not None:
        return _tts_singleton
    provider = (settings.TTS_PROVIDER or "mock").strip().lower()
    if provider == "openai" and settings.OPENAI_API_KEY:
        _tts_singleton = OpenAITTS(settings.OPENAI_API_KEY, voice=settings.TTS_VOICE)
        return _tts_singleton
    _tts_singleton = MockTTS()
    return _tts_singleton
