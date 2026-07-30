"""Shared speech contracts."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional


class SpeechEventType(str, Enum):
    SESSION_STARTED = "speech.session.started"
    SESSION_CLOSED = "speech.session.closed"
    STT_PARTIAL = "speech.stt.partial"
    STT_FINAL = "speech.stt.final"
    TTS_COMPLETE = "speech.tts.complete"
    ERROR = "speech.error"


@dataclass
class TranscriptSegment:
    text: str
    is_final: bool = True
    confidence: Optional[float] = None
    language: Optional[str] = None
    provider: str = "mock"
    model: str = "mock"


@dataclass
class SynthesisResult:
    audio: bytes
    mime_type: str = "audio/mpeg"
    provider: str = "mock"
    model: str = "mock"
    voice: Optional[str] = None


@dataclass
class SpeechEvent:
    event_type: SpeechEventType
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    payload: dict[str, Any] = field(default_factory=dict)
    timestamp: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    )

    def to_dict(self) -> dict[str, Any]:
        return {
            "event": self.event_type.value,
            "event_type": self.event_type.value,
            "session_id": self.session_id or "",
            "user_id": self.user_id or "",
            "timestamp": self.timestamp,
            "source": "deepiri-speech",
            **self.payload,
        }
