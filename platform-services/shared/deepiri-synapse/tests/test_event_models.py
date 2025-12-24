import unittest

from deepiri_modelkit.contracts import events

# Load validators module directly by file path to avoid package import issues
import importlib.util
from pathlib import Path

validators_path = Path(__file__).resolve().parents[1] / "app" / "schemas" / "validators.py"
spec = importlib.util.spec_from_file_location("deepiri_synapse.validators", str(validators_path))
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


class TestEventModels(unittest.TestCase):
    def test_modelready_event_valid(self):
        data = {"event": "model-ready", "version": "1.2.3", "model_id": "m-123"}
        ev = events.ModelReadyEvent(**data)
        self.assertEqual(ev.event, "model-ready")

    def test_inference_event_valid(self):
        data = {
            "event": "inference",
            "input": {"text": "hello"},
            "output": {"label": "greeting"},
            "latency_ms": 12.5,
        }
        ev = events.InferenceEvent(**data)
        self.assertEqual(ev.output["label"], "greeting")

    def test_training_event_valid(self):
        data = {"event": "training", "dataset": "ds1", "epoch": 3}
        ev = events.TrainingEvent(**data)
        self.assertEqual(ev.dataset, "ds1")

    def test_platform_event_and_error(self):
        pdata = {"event": "platform", "action": "restart"}
        perr = {"event": "error", "error_type": "Runtime", "message": "oops"}
        pev = events.PlatformEvent(**pdata)
        eev = events.ErrorEvent(**perr)
        self.assertEqual(pev.action, "restart")
        self.assertEqual(eev.error_type, "Runtime")

    def test_validate_event_helper_accepts_valid(self):
        data = {"event": "model-ready", "version": "1.0", "model_id": "m1"}
        out = v.validate_event("model-events", data)
        self.assertEqual(out["event"], "model-ready")

    def test_validate_event_helper_rejects_invalid(self):
        bad = {"event": "model-ready"}  # missing required 'version'
        with self.assertRaises(ValueError):
            v.validate_event("model-events", bad)


if __name__ == "__main__":
    unittest.main()
