"""
Event schema validators
Validates events against deepiri-modelkit schemas
"""
from typing import Dict, Any
from pydantic import ValidationError

# Import from modelkit (would need to install it)
try:
    from deepiri_modelkit.contracts.events import (
        ModelReadyEvent,
        InferenceEvent,
        PlatformEvent,
        AGIDecisionEvent,
        TrainingEvent
    )
    MODELKIT_AVAILABLE = True
except ImportError:
    MODELKIT_AVAILABLE = False


def validate_event(stream_name: str, event_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Validate event against schema
    
    Args:
        stream_name: Stream name
        event_data: Event data
    
    Returns:
        Validated event dict
    
    Raises:
        ValidationError: If event is invalid
    """
    if not MODELKIT_AVAILABLE:
        return event_data  # Skip validation if modelkit not available
    
    event_type = event_data.get("event")
    
    try:
        if stream_name == "model-events":
            if event_type == "model-ready":
                ModelReadyEvent(**event_data)
            elif event_type == "model-loaded":
                # ModelLoadedEvent(**event_data)
                pass
        elif stream_name == "inference-events":
            InferenceEvent(**event_data)
        elif stream_name == "platform-events":
            PlatformEvent(**event_data)
        elif stream_name == "agi-decisions":
            AGIDecisionEvent(**event_data)
        elif stream_name == "training-events":
            TrainingEvent(**event_data)
    except ValidationError as e:
        raise ValueError(f"Invalid event schema: {e}")
    
    return event_data

