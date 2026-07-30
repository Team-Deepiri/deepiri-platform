"""HTTP helpers for Jobs / Truss / workflow-orchestrator calling speech."""
from __future__ import annotations

import logging
from typing import Any, Optional

import httpx

from .settings import settings

logger = logging.getLogger("deepiri-speech.jobs")


class SpeechHttpClient:
    """Client used by Jobs/Truss *or* reverse probes from speech → orchestrator."""

    def __init__(self, base_url: Optional[str] = None, timeout: float = 120.0):
        self.base_url = (base_url or f"http://127.0.0.1:{settings.PORT}").rstrip("/")
        self.timeout = timeout

    async def health(self) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            r = await client.get(f"{self.base_url}/health")
            r.raise_for_status()
            return r.json()

    async def transcribe(
        self,
        audio: bytes,
        *,
        filename: str = "audio.wav",
        mime_type: str = "audio/wav",
        language: Optional[str] = None,
        session_id: Optional[str] = None,
    ) -> dict[str, Any]:
        data: dict[str, str] = {}
        if language:
            data["language"] = language
        if session_id:
            data["session_id"] = session_id
        files = {"file": (filename, audio, mime_type)}
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            r = await client.post(f"{self.base_url}/v1/stt", data=data, files=files)
            r.raise_for_status()
            return r.json()

    async def synthesize(
        self,
        text: str,
        *,
        voice: Optional[str] = None,
        session_id: Optional[str] = None,
    ) -> tuple[bytes, str]:
        body: dict[str, Any] = {"text": text}
        if voice:
            body["voice"] = voice
        if session_id:
            body["session_id"] = session_id
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            r = await client.post(f"{self.base_url}/v1/tts", json=body)
            r.raise_for_status()
            return r.content, r.headers.get("content-type", "application/octet-stream")


async def notify_orchestrator(event: str, payload: dict[str, Any]) -> None:
    """Best-effort notify Jobs/Truss (workflow-orchestrator) of speech lifecycle."""
    url = (settings.JOBS_URL or settings.TRUSS_URL or "").rstrip("/")
    if not url:
        return
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.post(
                f"{url}/speech/events",
                json={"event": event, "source": "deepiri-speech", **payload},
            )
    except Exception as exc:
        logger.debug("orchestrator notify skipped: %s", exc)
