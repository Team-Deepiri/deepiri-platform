"""STT/TTS providers — mock default; faster-whisper / Kokoro / OpenAI optional.

Device selection via app.device (CUDA → MPS → CPU).
Avoid XTTS-v2 (CPML) for commercial product paths.
"""
from __future__ import annotations

import asyncio
import io
import logging
import os
import wave
from pathlib import Path
from typing import Optional

from .contracts import SynthesisResult, TranscriptSegment
from .device import resolve_device
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
    """Default production STT on NVIDIA (CTranslate2). CPU/MPS hosts use CPU int8."""

    name = "faster_whisper"

    def __init__(self, model_size: str = "small.en"):
        self.model_size = model_size
        self._model = None

    def _load(self):
        if self._model is not None:
            return self._model
        from faster_whisper import WhisperModel

        device = resolve_device()
        self._model = WhisperModel(
            self.model_size,
            device=device.ctranslate2_device,
            compute_type=device.ctranslate2_compute_type,
        )
        logger.info(
            "faster-whisper loaded model=%s device=%s compute=%s",
            self.model_size,
            device.ctranslate2_device,
            device.ctranslate2_compute_type,
        )
        return self._model

    async def transcribe(
        self, audio: bytes, *, mime_type: str = "audio/wav", language: Optional[str] = None
    ) -> TranscriptSegment:
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


class WhisperCppSTT:
    """Optional Apple Silicon / edge STT via whisper.cpp bindings when installed."""

    name = "whisper_cpp"

    def __init__(self, model_size: str = "base.en"):
        self.model_size = model_size
        self._model = None

    def _load(self):
        if self._model is not None:
            return self._model
        try:
            from pywhispercpp.model import Model
        except ImportError as exc:
            raise ImportError(
                "pywhispercpp not installed; poetry install -E apple"
            ) from exc
        self._model = Model(self.model_size)
        return self._model

    async def transcribe(
        self, audio: bytes, *, mime_type: str = "audio/wav", language: Optional[str] = None
    ) -> TranscriptSegment:
        import tempfile

        def _run() -> TranscriptSegment:
            model = self._load()
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                tmp.write(audio)
                path = tmp.name
            try:
                segments = model.transcribe(path)
                text = " ".join(getattr(s, "text", str(s)).strip() for s in segments).strip()
                return TranscriptSegment(
                    text=text,
                    is_final=True,
                    language=language or "en",
                    provider=self.name,
                    model=self.model_size,
                )
            finally:
                try:
                    os.unlink(path)
                except OSError:
                    pass

        return await asyncio.to_thread(_run)


def _pcm16_mono_to_wav(pcm: bytes, sample_rate: int = 24000) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm)
    return buf.getvalue()


class KokoroTTS:
    """Kokoro-82M via kokoro-onnx — Apache/MIT, CPU/GPU/Apple-friendly default TTS."""

    name = "kokoro"

    def __init__(self, voice: str = "af_heart"):
        self.voice = voice
        self._kokoro = None

    def _model_paths(self) -> tuple[Path, Path]:
        root = Path(settings.KOKORO_MODEL_DIR).expanduser()
        model = Path(settings.KOKORO_MODEL_PATH).expanduser() if settings.KOKORO_MODEL_PATH else root / "kokoro-v1.0.onnx"
        voices = (
            Path(settings.KOKORO_VOICES_PATH).expanduser()
            if settings.KOKORO_VOICES_PATH
            else root / "voices-v1.0.bin"
        )
        return model, voices

    def _ensure_models(self) -> tuple[Path, Path]:
        model, voices = self._model_paths()
        if model.is_file() and voices.is_file():
            return model, voices
        if not settings.KOKORO_AUTO_DOWNLOAD:
            raise FileNotFoundError(
                f"Kokoro models missing at {model} / {voices}; "
                "set KOKORO_AUTO_DOWNLOAD=1 or place onnx + voices.bin"
            )
        model.parent.mkdir(parents=True, exist_ok=True)
        base = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
        import urllib.request

        for url, dest in (
            (f"{base}/kokoro-v1.0.onnx", model),
            (f"{base}/voices-v1.0.bin", voices),
        ):
            if dest.is_file():
                continue
            logger.info("Downloading Kokoro asset → %s", dest)
            urllib.request.urlretrieve(url, dest)  # noqa: S310 — pinned release URL
        return model, voices

    def _load(self):
        if self._kokoro is not None:
            return self._kokoro
        from kokoro_onnx import Kokoro

        model, voices = self._ensure_models()
        device = resolve_device()
        # kokoro-onnx uses onnxruntime; providers selected via env when supported
        os.environ.setdefault(
            "ONNXRUNTIME_PROVIDERS",
            ",".join(device.onnx_providers),
        )
        self._kokoro = Kokoro(str(model), str(voices))
        logger.info("Kokoro TTS loaded voice=%s device=%s", self.voice, device.kind)
        return self._kokoro

    async def synthesize(self, text: str, *, voice: Optional[str] = None) -> SynthesisResult:
        v = voice or self.voice or settings.TTS_VOICE or "af_heart"
        if v in ("default", "mock"):
            v = "af_heart"

        def _run() -> bytes:
            kokoro = self._load()
            samples, sample_rate = kokoro.create(text, voice=v, speed=1.0)
            import numpy as np

            pcm = (np.asarray(samples) * 32767.0).astype(np.int16).tobytes()
            return _pcm16_mono_to_wav(pcm, int(sample_rate))

        audio = await asyncio.to_thread(_run)
        return SynthesisResult(
            audio=audio,
            mime_type="audio/wav",
            provider=self.name,
            model="kokoro-82m",
            voice=v,
        )


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
    if provider in ("whisper_cpp", "whisper.cpp", "whisper-cpp"):
        try:
            _stt_singleton = WhisperCppSTT(settings.STT_MODEL)
            return _stt_singleton
        except ImportError:
            logger.warning("whisper.cpp bindings missing; falling back")
    if provider in ("faster_whisper", "faster-whisper", "whisper"):
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
    if provider in ("kokoro", "kokoro-onnx", "kokoro_onnx"):
        try:
            import kokoro_onnx  # noqa: F401

            _tts_singleton = KokoroTTS(voice=settings.TTS_VOICE or "af_heart")
            return _tts_singleton
        except ImportError:
            logger.warning("kokoro-onnx not installed; falling back to mock")
    if provider in ("xtts", "xtts_v2", "xtts-v2"):
        logger.error(
            "XTTS-v2 is CPML (non-commercial) — refused for product; use kokoro or piper"
        )
    _tts_singleton = MockTTS()
    return _tts_singleton


def reset_provider_singletons() -> None:
    global _stt_singleton, _tts_singleton
    _stt_singleton = None
    _tts_singleton = None
