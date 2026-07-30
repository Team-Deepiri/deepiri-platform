"""Control-plane events → Redis Streams (speech-events) + pub/sub partials."""
from __future__ import annotations

import json
import logging
from typing import Any, Optional

import redis.asyncio as aioredis

from .contracts import SpeechEvent, SpeechEventType
from .settings import settings

logger = logging.getLogger("deepiri-speech.bus")


class SpeechBus:
    def __init__(self) -> None:
        self._redis: Optional[aioredis.Redis] = None

    async def connect(self) -> None:
        if self._redis is None:
            self._redis = aioredis.Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                password=settings.REDIS_PASSWORD or None,
                db=settings.REDIS_DB,
                decode_responses=True,
            )

    async def close(self) -> None:
        if self._redis is not None:
            await self._redis.aclose()
            self._redis = None

    async def publish_stream(self, event: SpeechEvent) -> None:
        """XADD to speech-events (lifecycle). Failures are non-fatal."""
        await self.connect()
        assert self._redis is not None
        flat: dict[str, str] = {}
        for k, v in event.to_dict().items():
            if v is None:
                continue
            if isinstance(v, (dict, list)):
                flat[k] = json.dumps(v)
            else:
                flat[k] = str(v)
        try:
            await self._redis.xadd(settings.SPEECH_STREAM, flat)
        except Exception as exc:
            logger.warning("speech stream publish failed: %s", exc)

    async def publish_partial(self, session_id: str, message: dict[str, Any]) -> None:
        await self.connect()
        assert self._redis is not None
        channel = f"{settings.SPEECH_CHANNEL_PREFIX}:{session_id}"
        try:
            await self._redis.publish(channel, json.dumps(message))
        except Exception as exc:
            logger.warning("speech pub/sub failed: %s", exc)

    async def session_started(self, session_id: str, user_id: Optional[str] = None, **payload):
        await self.publish_stream(
            SpeechEvent(
                event_type=SpeechEventType.SESSION_STARTED,
                session_id=session_id,
                user_id=user_id,
                payload=payload,
            )
        )

    async def stt_final(self, session_id: Optional[str], text: str, **payload):
        await self.publish_stream(
            SpeechEvent(
                event_type=SpeechEventType.STT_FINAL,
                session_id=session_id,
                payload={"text": text, **payload},
            )
        )


_bus: Optional[SpeechBus] = None


async def get_bus() -> SpeechBus:
    global _bus
    if _bus is None:
        _bus = SpeechBus()
        await _bus.connect()
    return _bus
