"""Silero VAD — optional; falls back to always-speech when extras missing."""
from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

import numpy as np

from .settings import settings

logger = logging.getLogger("deepiri-speech.vad")


@dataclass
class VadResult:
    has_speech: bool
    speech_ratio: float = 0.0
    provider: str = "passthrough"


class PassthroughVAD:
    """Treat any non-empty audio as speech (dev / no extras)."""

    name = "passthrough"

    def analyze(self, audio: bytes, *, sample_rate: int = 16000) -> VadResult:
        return VadResult(
            has_speech=len(audio) > 0,
            speech_ratio=1.0 if audio else 0.0,
            provider=self.name,
        )


class SileroVAD:
    name = "silero"

    def __init__(self, threshold: float = 0.5):
        self.threshold = threshold
        self._model = None
        self._utils = None

    def _load(self):
        if self._model is not None:
            return
        import torch

        model, utils = torch.hub.load(
            repo_or_dir="snakers4/silero-vad",
            model="silero_vad",
            trust_repo=True,
        )
        self._model = model
        self._utils = utils
        logger.info("Silero VAD model loaded")

    def analyze(self, audio: bytes, *, sample_rate: int = 16000) -> VadResult:
        self._load()
        get_speech_timestamps = self._utils[0]

        # Interpret raw bytes as int16 PCM when possible; otherwise passthrough.
        if len(audio) < 2:
            return VadResult(has_speech=False, speech_ratio=0.0, provider=self.name)

        try:
            pcm = np.frombuffer(audio, dtype=np.int16).astype(np.float32) / 32768.0
        except ValueError:
            return VadResult(has_speech=True, speech_ratio=1.0, provider=self.name)

        if pcm.size == 0:
            return VadResult(has_speech=False, speech_ratio=0.0, provider=self.name)

        import torch

        waveform = torch.from_numpy(pcm)
        timestamps = get_speech_timestamps(
            waveform,
            self._model,
            sampling_rate=sample_rate,
            threshold=self.threshold,
        )
        if not timestamps:
            return VadResult(has_speech=False, speech_ratio=0.0, provider=self.name)

        speech_samples = sum(t["end"] - t["start"] for t in timestamps)
        ratio = float(speech_samples) / float(max(pcm.size, 1))
        return VadResult(has_speech=ratio > 0.01, speech_ratio=ratio, provider=self.name)


_vad: Optional[PassthroughVAD | SileroVAD] = None


def get_vad():
    global _vad
    if _vad is not None:
        return _vad

    if not settings.ENABLE_SILERO_VAD:
        _vad = PassthroughVAD()
        return _vad

    try:
        import torch  # noqa: F401

        _vad = SileroVAD(threshold=settings.SILERO_VAD_THRESHOLD)
        # Probe load lazily on first analyze
        return _vad
    except ImportError:
        logger.warning("torch/silero unavailable; VAD passthrough")
        _vad = PassthroughVAD()
        return _vad
