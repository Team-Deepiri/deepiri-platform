from __future__ import annotations

import re
from typing import Any

EMAIL_RE = re.compile(r"([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\\.[A-Za-z]{2,})")
BEARER_RE = re.compile(r"(?i)(bearer\\s+)[A-Za-z0-9._\\-+/=]+")
KEY_VALUE_RE = re.compile(
    r"(?i)\\b(api[_-]?key|token|secret|password)\\b\\s*[:=]\\s*([\\\"']?)([^\\s,;\\\"']+)"
)
SENSITIVE_KEYS = {
    "api_key",
    "apikey",
    "token",
    "secret",
    "password",
    "authorization",
    "access_token",
    "refresh_token",
}


def _mask_string(value: str) -> str:
    masked = EMAIL_RE.sub("***@***", value)
    masked = BEARER_RE.sub(r"\\1***", masked)
    masked = KEY_VALUE_RE.sub(lambda m: f"{m.group(1)}={m.group(2)}***", masked)
    return masked


def scrub_pii(value: Any) -> Any:
    if isinstance(value, str):
        return _mask_string(value)

    if isinstance(value, dict):
        out: dict[str, Any] = {}
        for key, item in value.items():
            normalized = str(key).lower().replace("-", "_")
            if normalized in SENSITIVE_KEYS:
                out[str(key)] = "***"
            else:
                out[str(key)] = scrub_pii(item)
        return out

    if isinstance(value, list):
        return [scrub_pii(item) for item in value]

    if isinstance(value, tuple):
        return tuple(scrub_pii(item) for item in value)

    if isinstance(value, set):
        return {scrub_pii(item) for item in value}

    return value


def deepiri_schema_processor(logger: Any, method_name: str, event_dict: dict[str, Any]) -> dict[str, Any]:
    message = scrub_pii(str(event_dict.pop("event", "")))
    timestamp = event_dict.pop("timestamp", None)
    level = str(event_dict.pop("level", method_name)).upper()
    service_name = str(event_dict.pop("service_name", "unknown-service"))
    version = str(event_dict.pop("version", "unknown"))
    trace_id = str(event_dict.pop("trace_id", ""))

    return {
        "timestamp": timestamp,
        "level": level,
        "service_name": service_name,
        "version": version,
        "trace_id": trace_id,
        "message": message,
        "context": scrub_pii(event_dict),
    }
