import os

# Keep unit tests free of LiveKit reconnect loops / network
os.environ.setdefault("LIVEKIT_WORKER_ENABLED", "0")
os.environ.setdefault("PIPECAT_ENABLED", "1")
os.environ.setdefault("STT_PROVIDER", "mock")
os.environ.setdefault("TTS_PROVIDER", "mock")

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
