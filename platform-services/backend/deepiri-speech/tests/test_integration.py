"""Integration/API-contract coverage: WebSocket session, LiveKit token/rooms, provider selection.

External services (LiveKit server, Redis, provider backends) are mocked or unavailable;
we assert application behavior and response contracts.
"""
import base64

import pytest
from fastapi.testclient import TestClient

from app import main as app_main
from app.main import app
from app.providers import MockSTT, MockTTS, OpenAISTT, OpenAITTS, get_stt, get_tts, reset_provider_singletons
from app.settings import settings

MOCK_WAV = b"RIFF....fake-wav-data"


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def _b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def test_ws_session_roundtrip(client: TestClient):
    with client.websocket_connect("/v1/session/ws") as ws:
        ready = ws.receive_json()
        assert ready["type"] == "session_ready"
        assert "session_id" in ready

        ws.send_json(
            {
                "type": "stt",
                "audio_b64": _b64(MOCK_WAV),
                "mime_type": "audio/wav",
            }
        )
        final = ws.receive_json()
        assert final["type"] == "stt_final"
        assert "mock transcript" in final["text"]
        assert final["provider"] == "mock"


def test_livekit_token_success(client: TestClient, monkeypatch):
    monkeypatch.setattr(app_main, "mint_token", lambda **kw: "minted.jwt.token")
    r = client.post("/v1/livekit/token", json={"identity": "u1", "room_name": "voice-1"})
    assert r.status_code == 200
    data = r.json()
    assert data["token"] == "minted.jwt.token"
    assert data["room_name"] == "voice-1"
    assert data["identity"] == "u1"
    assert "url" in data
    assert "room_create" in data["grants"]


def test_livekit_token_graceful_error(client: TestClient, monkeypatch):
    def boom(**kw):
        raise RuntimeError("livekit unavailable")

    monkeypatch.setattr(app_main, "mint_token", boom)
    r = client.post("/v1/livekit/token", json={"identity": "u1"})
    assert r.status_code == 200
    data = r.json()
    assert "error" in data
    assert data["identity"] == "u1"


def test_livekit_rooms_list(client: TestClient, monkeypatch):
    async def fake_list():
        return ["deepiri-voice"]

    monkeypatch.setattr(app_main, "list_rooms", fake_list)
    r = client.get("/v1/livekit/rooms")
    assert r.status_code == 200
    data = r.json()
    assert data["rooms"] == ["deepiri-voice"]
    assert "url" in data


def test_livekit_rooms_graceful_error(client: TestClient, monkeypatch):
    async def boom():
        raise RuntimeError("livekit unavailable")

    monkeypatch.setattr(app_main, "list_rooms", boom)
    r = client.get("/v1/livekit/rooms")
    assert r.status_code == 200
    data = r.json()
    assert data["rooms"] == []
    assert "error" in data


def test_provider_selection_openai(monkeypatch):
    monkeypatch.setattr(settings, "STT_PROVIDER", "openai")
    monkeypatch.setattr(settings, "TTS_PROVIDER", "openai")
    monkeypatch.setattr(settings, "OPENAI_API_KEY", "sk-test")
    reset_provider_singletons()
    try:
        assert isinstance(get_stt(), OpenAISTT)
        assert isinstance(get_tts(), OpenAITTS)
    finally:
        reset_provider_singletons()


def test_provider_selection_falls_back_to_mock(monkeypatch):
    monkeypatch.setattr(settings, "STT_PROVIDER", "faster_whisper")
    monkeypatch.setattr(settings, "TTS_PROVIDER", "kokoro")
    reset_provider_singletons()
    try:
        assert isinstance(get_stt(), MockSTT)
        assert isinstance(get_tts(), MockTTS)
    finally:
        reset_provider_singletons()
