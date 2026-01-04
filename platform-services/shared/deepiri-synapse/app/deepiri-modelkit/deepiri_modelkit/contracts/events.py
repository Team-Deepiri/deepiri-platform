"""
Pydantic event models for deepiri modelkit contracts.

This module defines simple, reviewable event schemas used by
`platform-services/shared/deepiri-synapse` for runtime validation.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional, Literal

from pydantic import BaseModel, Field, validator


class BaseEvent(BaseModel):
    event: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    model_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

    @validator("timestamp", pre=True, always=True)
    def ensure_timestamp(cls, v):
        if v is None:
            return datetime.utcnow()
        return v


class ModelReadyEvent(BaseEvent):
    event: Literal["model-ready"]
    version: str
    artifacts: Optional[List[str]] = None


class InferenceEvent(BaseEvent):
    event: Literal["inference"]
    input: Dict[str, Any]
    output: Dict[str, Any]
    latency_ms: Optional[float] = None

    @validator("latency_ms", pre=True)
    def coerce_latency(cls, v):
        if v is None:
            return None
        try:
            return float(v)
        except (TypeError, ValueError):
            raise ValueError("latency_ms must be a number")


class TrainingEvent(BaseEvent):
    event: Literal["training"]
    dataset: str
    epoch: Optional[int] = None
    loss: Optional[float] = None


class PlatformEvent(BaseEvent):
    event: Literal["platform"]
    action: str
    details: Optional[Dict[str, Any]] = None


class ErrorEvent(BaseEvent):
    event: Literal["error"]
    error_type: str
    message: str
    traceback: Optional[str] = None


class AGIDecisionEvent(BaseEvent):
    event: Literal["agi-decision"]
    decision: Dict[str, Any]
    confidence: Optional[float] = None



__all__ = [
    "BaseEvent",
    "ModelReadyEvent",
    "InferenceEvent",
    "TrainingEvent",
    "PlatformEvent",
    "ErrorEvent",
    "AGIDecisionEvent",
]
