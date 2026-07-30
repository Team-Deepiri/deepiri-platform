"""LiveKit room + access-token helpers (full grants for WebRTC duplex)."""
from __future__ import annotations

import logging
from typing import Any, Optional

from .settings import settings

logger = logging.getLogger("deepiri-speech.livekit_rooms")


def _http_url() -> str:
    """LiveKit API expects http(s), not ws(s)."""
    url = settings.LIVEKIT_URL.strip()
    if url.startswith("ws://"):
        return "http://" + url[len("ws://") :]
    if url.startswith("wss://"):
        return "https://" + url[len("wss://") :]
    return url


def mint_token(
    *,
    room_name: str,
    identity: str,
    name: Optional[str] = None,
    agent: bool = False,
    can_publish: bool = True,
    can_subscribe: bool = True,
    room_admin: bool = False,
    room_create: bool = False,
    ttl_hours: int = 6,
) -> str:
    from livekit.api import AccessToken, VideoGrants
    from datetime import timedelta

    grants = VideoGrants(
        room_join=True,
        room=room_name,
        room_create=room_create,
        room_admin=room_admin,
        can_publish=can_publish,
        can_subscribe=can_subscribe,
        can_publish_data=True,
        can_update_own_metadata=True,
    )
    # Agent flag when supported by installed livekit-api
    try:
        grants.agent = agent  # type: ignore[attr-defined]
    except Exception:
        pass

    token = (
        AccessToken(settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET)
        .with_identity(identity)
        .with_name(name or identity)
        .with_grants(grants)
        .with_ttl(timedelta(hours=ttl_hours))
    )
    # Some versions expose with_kind("agent")
    if agent:
        try:
            token = token.with_kind("agent")  # type: ignore[attr-defined]
        except Exception:
            pass
    return token.to_jwt()


async def create_room(
    name: Optional[str] = None,
    *,
    empty_timeout: Optional[int] = None,
    max_participants: Optional[int] = None,
) -> dict[str, Any]:
    from livekit import api

    room_name = name or settings.LIVEKIT_DEFAULT_ROOM
    lkapi = None
    try:
        lkapi = api.LiveKitAPI(
            _http_url(), settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET
        )
        room = await lkapi.room.create_room(
            api.CreateRoomRequest(
                name=room_name,
                empty_timeout=empty_timeout or settings.LIVEKIT_ROOM_EMPTY_TIMEOUT,
                max_participants=max_participants
                or settings.LIVEKIT_ROOM_MAX_PARTICIPANTS,
            )
        )
        return {
            "name": room.name,
            "sid": room.sid,
            "empty_timeout": room.empty_timeout,
            "max_participants": room.max_participants,
            "num_participants": getattr(room, "num_participants", 0),
            "livekit_url": settings.LIVEKIT_PUBLIC_URL,
        }
    finally:
        if lkapi is not None:
            await lkapi.aclose()


async def list_rooms() -> list[dict[str, Any]]:
    from livekit import api

    lkapi = None
    try:
        lkapi = api.LiveKitAPI(
            _http_url(), settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET
        )
        resp = await lkapi.room.list_rooms(api.ListRoomsRequest())
        rooms = []
        for room in resp.rooms or []:
            rooms.append(
                {
                    "name": room.name,
                    "sid": room.sid,
                    "num_participants": getattr(room, "num_participants", 0),
                    "max_participants": room.max_participants,
                    "empty_timeout": room.empty_timeout,
                }
            )
        return rooms
    finally:
        if lkapi is not None:
            await lkapi.aclose()


async def delete_room(name: str) -> dict[str, Any]:
    from livekit import api

    lkapi = None
    try:
        lkapi = api.LiveKitAPI(
            _http_url(), settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET
        )
        await lkapi.room.delete_room(api.DeleteRoomRequest(room=name))
        return {"deleted": name}
    finally:
        if lkapi is not None:
            await lkapi.aclose()


async def ensure_default_room() -> dict[str, Any]:
    try:
        rooms = await list_rooms()
        for r in rooms:
            if r["name"] == settings.LIVEKIT_DEFAULT_ROOM:
                return {**r, "livekit_url": settings.LIVEKIT_PUBLIC_URL, "ensured": True}
        return await create_room(settings.LIVEKIT_DEFAULT_ROOM)
    except Exception as exc:
        logger.warning("ensure_default_room failed: %s", exc)
        return {
            "name": settings.LIVEKIT_DEFAULT_ROOM,
            "livekit_url": settings.LIVEKIT_PUBLIC_URL,
            "ensured": False,
            "error": str(exc),
        }
