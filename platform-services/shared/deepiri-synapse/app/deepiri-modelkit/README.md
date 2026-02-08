# deepiri_modelkit — event models

This package contains small Pydantic event models used for validating runtime
events in the platform. The primary module is `deepiri_modelkit.contracts.events`.

Event models
------------

- **BaseEvent**: common fields shared by all events.
	- Fields: `event` (str), `timestamp` (datetime, default now), `model_id` (optional str),
		`metadata` (optional dict).

- **ModelReadyEvent**: signals a model artifact/version is ready for serving.
	- Fields: `event` == "model-ready", `version` (str), `artifacts` (optional list of str).

- **InferenceEvent**: records an inference request/response.
	- Fields: `event` == "inference", `input` (dict), `output` (dict), `latency_ms` (optional float).
	- Notes: `latency_ms` is coerced to float if possible.

- **TrainingEvent**: records training progress or metadata.
	- Fields: `event` == "training", `dataset` (str), `epoch` (optional int), `loss` (optional float).

- **PlatformEvent**: operational or platform-level events.
	- Fields: `event` == "platform", `action` (str), `details` (optional dict).

- **ErrorEvent**: captures errors/exceptions raised by components.
	- Fields: `event` == "error", `error_type` (str), `message` (str), `traceback` (optional str).

- **AGIDecisionEvent**: records decisions produced by AGI workflow components.
	- Fields: `event` == "agi-decision", `decision` (dict), `confidence` (optional float).

Usage
-----

Import the models from `deepiri_modelkit.contracts.events` and instantiate or validate
event dictionaries using the Pydantic models. Example:

```py
from deepiri_modelkit.contracts.events import ModelReadyEvent

ev = ModelReadyEvent(event="model-ready", version="1.2.3", model_id="m-123")
```

The models are intentionally small and explicit so they are easy to review and
use for runtime validation across services.
