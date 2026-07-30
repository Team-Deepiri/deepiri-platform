import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "healthy"
    assert data["service"] == "deepiri-speech"


def test_stt_mock(client):
    r = client.post(
        "/v1/stt",
        files={"file": ("a.wav", b"RIFF....fake", "audio/wav")},
    )
    assert r.status_code == 200
    assert "mock transcript" in r.json()["text"]


def test_tts_mock(client):
    r = client.post("/v1/tts", json={"text": "hello"})
    assert r.status_code == 200
    assert r.content.startswith(b"MOCK_TTS:")


def test_session_create(client):
    r = client.post("/v1/sessions", json={"user_id": "u1"})
    assert r.status_code == 200
    assert "session_id" in r.json()
    assert "room_name" in r.json()


def test_worker_status(client):
    r = client.get("/v1/worker/status")
    assert r.status_code == 200
    data = r.json()
    assert "enabled" in data
    assert "backend" in data


def test_providers_includes_vad(client):
    r = client.get("/providers")
    assert r.status_code == 200
    assert "vad" in r.json()
