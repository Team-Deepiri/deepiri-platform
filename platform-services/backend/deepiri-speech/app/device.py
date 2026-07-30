"""Cross-platform inference device selection: CUDA → MPS → CPU.

Works on Linux/Windows/macOS without requiring torch at import time.
faster-whisper uses CTranslate2 devices (cuda/cpu); torch/MPS used for VAD/Kokoro.
"""
from __future__ import annotations

import logging
import os
import platform
from dataclasses import dataclass
from functools import lru_cache
from typing import Literal

logger = logging.getLogger("deepiri-speech.device")

DeviceKind = Literal["cuda", "mps", "cpu"]


@dataclass(frozen=True)
class DeviceInfo:
    """Resolved runtime device for speech engines."""

    kind: DeviceKind
    torch_device: str  # "cuda", "cuda:0", "mps", "cpu"
    ctranslate2_device: str  # faster-whisper: "cuda" | "cpu" (no MPS)
    ctranslate2_compute_type: str  # float16 | int8 | int8_float16
    onnx_providers: tuple[str, ...]
    platform: str
    machine: str
    detail: str = ""

    def to_dict(self) -> dict:
        return {
            "kind": self.kind,
            "torch_device": self.torch_device,
            "ctranslate2_device": self.ctranslate2_device,
            "ctranslate2_compute_type": self.ctranslate2_compute_type,
            "onnx_providers": list(self.onnx_providers),
            "platform": self.platform,
            "machine": self.machine,
            "detail": self.detail,
        }


def _env_override() -> DeviceKind | None:
    raw = (
        os.environ.get("SPEECH_DEVICE")
        or os.environ.get("DEVICE")
        or ""
    ).strip().lower()
    if not raw:
        try:
            from .settings import settings

            raw = (settings.SPEECH_DEVICE or "auto").strip().lower()
        except Exception:
            raw = "auto"
    if raw in ("cuda", "gpu", "nvidia"):
        return "cuda"
    if raw in ("mps", "metal", "apple"):
        return "mps"
    if raw in ("cpu",):
        return "cpu"
    if raw in ("auto", ""):
        return None
    logger.warning("Unknown SPEECH_DEVICE=%s; using auto", raw)
    return None


def _cuda_available() -> bool:
    try:
        import torch

        return bool(torch.cuda.is_available())
    except Exception:
        return False


def _mps_available() -> bool:
    if platform.system() != "Darwin":
        return False
    try:
        import torch

        return bool(getattr(torch.backends, "mps", None) and torch.backends.mps.is_available())
    except Exception:
        return False


def _onnx_providers_for(kind: DeviceKind) -> tuple[str, ...]:
    """Prefer GPU EP when present; always end with CPUExecutionProvider."""
    if kind == "cuda":
        return ("CUDAExecutionProvider", "CPUExecutionProvider")
    if kind == "mps":
        # CoreML EP when available on Apple Silicon ONNX builds
        return ("CoreMLExecutionProvider", "CPUExecutionProvider")
    return ("CPUExecutionProvider",)


@lru_cache(maxsize=1)
def resolve_device() -> DeviceInfo:
    override = _env_override()
    plat = platform.system()
    machine = platform.machine()

    if override == "cpu":
        info = DeviceInfo(
            kind="cpu",
            torch_device="cpu",
            ctranslate2_device="cpu",
            ctranslate2_compute_type="int8",
            onnx_providers=_onnx_providers_for("cpu"),
            platform=plat,
            machine=machine,
            detail="forced cpu",
        )
    elif override == "cuda" or (override is None and _cuda_available()):
        if override == "cuda" and not _cuda_available():
            logger.warning("SPEECH_DEVICE=cuda but CUDA unavailable; falling back to CPU")
            info = DeviceInfo(
                kind="cpu",
                torch_device="cpu",
                ctranslate2_device="cpu",
                ctranslate2_compute_type="int8",
                onnx_providers=_onnx_providers_for("cpu"),
                platform=plat,
                machine=machine,
                detail="cuda requested but unavailable",
            )
        else:
            info = DeviceInfo(
                kind="cuda",
                torch_device="cuda",
                ctranslate2_device="cuda",
                ctranslate2_compute_type="float16",
                onnx_providers=_onnx_providers_for("cuda"),
                platform=plat,
                machine=machine,
                detail="NVIDIA CUDA",
            )
    elif override == "mps" or (override is None and _mps_available()):
        if override == "mps" and not _mps_available():
            logger.warning("SPEECH_DEVICE=mps but MPS unavailable; falling back to CPU")
            info = DeviceInfo(
                kind="cpu",
                torch_device="cpu",
                ctranslate2_device="cpu",
                ctranslate2_compute_type="int8",
                onnx_providers=_onnx_providers_for("cpu"),
                platform=plat,
                machine=machine,
                detail="mps requested but unavailable",
            )
        else:
            # faster-whisper/CTranslate2 has no MPS — use CPU int8; torch VAD/Kokoro can use MPS
            info = DeviceInfo(
                kind="mps",
                torch_device="mps",
                ctranslate2_device="cpu",
                ctranslate2_compute_type="int8",
                onnx_providers=_onnx_providers_for("mps"),
                platform=plat,
                machine=machine,
                detail="Apple Silicon MPS (STT via CPU CTranslate2)",
            )
    else:
        info = DeviceInfo(
            kind="cpu",
            torch_device="cpu",
            ctranslate2_device="cpu",
            ctranslate2_compute_type="int8",
            onnx_providers=_onnx_providers_for("cpu"),
            platform=plat,
            machine=machine,
            detail="CPU fallback",
        )

    logger.info(
        "speech device kind=%s torch=%s ctranslate2=%s/%s os=%s/%s (%s)",
        info.kind,
        info.torch_device,
        info.ctranslate2_device,
        info.ctranslate2_compute_type,
        info.platform,
        info.machine,
        info.detail,
    )
    return info


def clear_device_cache() -> None:
    resolve_device.cache_clear()
