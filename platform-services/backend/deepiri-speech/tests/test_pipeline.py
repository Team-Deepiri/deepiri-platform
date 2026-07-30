"""Device + pipeline status tests."""
from app.device import clear_device_cache, resolve_device
from app.pipecat_bridge import status_dict
from app.pipeline import VoicePipeline


def test_resolve_device_cpu_or_better():
    clear_device_cache()
    info = resolve_device()
    assert info.kind in ("cuda", "mps", "cpu")
    assert info.ctranslate2_device in ("cuda", "cpu")
    assert info.torch_device
    d = info.to_dict()
    assert "kind" in d


def test_pipecat_status_shape():
    s = status_dict()
    assert s["separate_service"] is False
    assert s["in_process"] is True
    assert s["auto_enabled"] is True
    assert "transports" in s
    assert "available" in s


def test_pipeline_status_endpoint(client):
    r = client.get("/v1/pipeline/status")
    assert r.status_code == 200
    data = r.json()
    assert "pipecat" in data
    assert data["pipecat"]["separate_service"] is False
    assert "endpoints" in data


def test_health_includes_device(client):
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert "device" in data
    assert "livekit" in data
    assert "pipecat" in data


async def test_voice_pipeline_mock_turn():
    pipe = VoicePipeline("test-session")
    turn = await pipe.process_audio(b"RIFF....fake", mime_type="audio/wav")
    assert turn.orchestrator in ("native", "pipecat")
    assert "mock transcript" in turn.transcript or turn.meta.get("skipped")
