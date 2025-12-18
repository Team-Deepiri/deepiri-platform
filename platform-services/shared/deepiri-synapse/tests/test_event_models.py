import pytest
from datetime import datetime

from deepiri_modelkit.contracts import events
from platform_services.shared.deepiri_synapse.app.schemas import validators as v


def test_modelready_event_valid():
    data = {
        "event": "model-ready",
        "version": "1.2.3",
        "model_id": "m-123",
    }
    ev = events.ModelReadyEvent(**data)
    assert ev.event == "model-ready"


def test_inference_event_valid():
    data = {
        "event": "inference",
        "input": {"text": "hello"},
        "output": {"label": "greeting"},
        "latency_ms": 12.5,
    }
    ev = events.InferenceEvent(**data)
    assert ev.output["label"] == "greeting"


def test_training_event_valid():
    data = {
        "event": "training",
        "dataset": "ds1",
        "epoch": 3,
    }
    ev = events.TrainingEvent(**data)
    assert ev.dataset == "ds1"


def test_platform_event_and_error():
    pdata = {"event": "platform", "action": "restart"}
    perr = {"event": "error", "error_type": "Runtime", "message": "oops"}
    pev = events.PlatformEvent(**pdata)
    eev = events.ErrorEvent(**perr)
    assert pev.action == "restart"
    assert eev.error_type == "Runtime"


def test_validate_event_helper_accepts_valid():
    # This exercises the validators.validate_event wrapper
    data = {"event": "model-ready", "version": "1.0", "model_id": "m1"}
    out = v.validate_event("model-events", data)
    assert out["event"] == "model-ready"


def test_validate_event_helper_rejects_invalid():
    bad = {"event": "model-ready"}  # missing required 'version'
    with pytest.raises(ValueError):
        v.validate_event("model-events", bad)
