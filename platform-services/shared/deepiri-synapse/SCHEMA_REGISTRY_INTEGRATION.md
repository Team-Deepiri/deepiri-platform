# Schema Registry, Validation Middleware, and Dead Letter Queue Integration

## Overview

This document explains how to integrate the new components:
1. **Schema Registry** - Manages event schema versions
2. **Validation Middleware** - Validates events before publishing
3. **Dead Letter Queue** - Stores invalid events for debugging

---

## Components Created

### 1. Schema Registry (`app/schemas/registry.py`)

Manages event schema versions and compatibility.

**Features:**
- Register schema versions
- Check schema compatibility
- Retrieve schemas by version
- List all registered schemas

**Usage:**
```python
from app.schemas.registry import SchemaRegistry, SchemaCompatibility

# Initialize
schema_registry = SchemaRegistry(redis_client)

# Register a schema version
await schema_registry.register_schema(
    stream_name="model-events",
    event_type="model-ready",
    schema_version="1.0.0",
    schema_definition={
        "type": "object",
        "properties": {
            "event": {"type": "string"},
            "model_name": {"type": "string"},
            "version": {"type": "string"}
        },
        "required": ["event", "model_name", "version"]
    },
    compatibility=SchemaCompatibility.BACKWARD
)

# Get latest schema
schema = await schema_registry.get_schema(
    stream_name="model-events",
    event_type="model-ready"
)

# List all versions
versions = await schema_registry.list_versions(
    stream_name="model-events",
    event_type="model-ready"
)
```

### 2. Validation Middleware (`app/middleware/validation.py`)

Intercepts events and validates them before publishing.

**Features:**
- Validates events against schemas
- Checks schema registry for version compatibility
- Sends invalid events to dead letter queue
- Tracks validation statistics

**Usage:**
```python
from app.middleware.validation import ValidationMiddleware
from app.schemas.registry import SchemaRegistry
from app.streams.dead_letter_queue import DeadLetterQueue

# Initialize components
schema_registry = SchemaRegistry(redis_client)
dead_letter_queue = DeadLetterQueue(redis_client)

# Create validation middleware
validation_middleware = ValidationMiddleware(
    redis_client=redis_client,
    schema_registry=schema_registry,
    dead_letter_queue=dead_letter_queue,
    enable_validation=True,
    enable_schema_registry=True
)

# Validate and publish event
success, message_id, error = await validation_middleware.validate_and_publish(
    stream_name="model-events",
    event_data={
        "event": "model-ready",
        "model_name": "classifier",
        "version": "1.0.0"
    }
)

if success:
    print(f"Event published: {message_id}")
else:
    print(f"Validation failed: {error}")

# Get statistics
stats = validation_middleware.get_stats()
print(f"Validated: {stats['validated']}, Invalid: {stats['invalid']}")
```

### 3. Dead Letter Queue (`app/streams/dead_letter_queue.py`)

Stores events that failed validation or processing.

**Features:**
- Stores failed events with error details
- Retry failed events
- Track failure statistics
- Query failed events by stream or failure type

**Usage:**
```python
from app.streams.dead_letter_queue import DeadLetterQueue

# Initialize
dead_letter_queue = DeadLetterQueue(redis_client)

# Get failed events
failed_events = await dead_letter_queue.get_failed_events(
    stream_name="model-events",
    count=10,
    failure_type="validation_error"
)

for event in failed_events:
    print(f"Failed: {event['error_message']}")
    print(f"Can retry: {event['can_retry']}")

# Retry a failed event
success, new_msg_id, error = await dead_letter_queue.retry_event(
    stream_name="model-events",
    dlq_message_id="1234567890-0",
    validation_middleware=validation_middleware
)

# Get DLQ statistics
stats = await dead_letter_queue.get_dlq_stats(stream_name="model-events")
print(f"Failed events: {stats['failed_events_count']}")
```

---

## Integration with Event Publisher

The `EventPublisher` has been updated to use validation middleware:

```python
from app.producers.event_publisher import EventPublisher
from app.middleware.validation import ValidationMiddleware

# Create validation middleware
validation_middleware = ValidationMiddleware(
    redis_client=redis_client,
    schema_registry=schema_registry,
    dead_letter_queue=dead_letter_queue
)

# Create event publisher with validation
publisher = EventPublisher(
    redis_client=redis_client,
    validation_middleware=validation_middleware
)

# Publish events (automatically validated)
await publisher.publish_model_event(
    event_type="model-ready",
    model_name="classifier",
    version="1.0.0"
)
```

---

## Integration with Main Application

Update `app/main.py` to initialize these components:

```python
from app.schemas.registry import SchemaRegistry
from app.middleware.validation import ValidationMiddleware
from app.streams.dead_letter_queue import DeadLetterQueue
from app.producers.event_publisher import EventPublisher

# In startup()
schema_registry = SchemaRegistry(redis_client)
dead_letter_queue = DeadLetterQueue(redis_client)
validation_middleware = ValidationMiddleware(
    redis_client=redis_client,
    schema_registry=schema_registry,
    dead_letter_queue=dead_letter_queue
)
event_publisher = EventPublisher(
    redis_client=redis_client,
    validation_middleware=validation_middleware
)

# Make available globally or via dependency injection
app.state.schema_registry = schema_registry
app.state.dead_letter_queue = dead_letter_queue
app.state.validation_middleware = validation_middleware
app.state.event_publisher = event_publisher
```

---

## API Endpoints to Add

Add these endpoints to `app/main.py`:

```python
@app.get("/schemas")
async def list_schemas():
    """List all registered schemas"""
    schemas = await schema_registry.get_all_schemas()
    return {"schemas": schemas}

@app.get("/schemas/{stream_name}/{event_type}")
async def get_schema(stream_name: str, event_type: str, version: str = None):
    """Get schema for stream/event type"""
    schema = await schema_registry.get_schema(stream_name, event_type, version)
    if not schema:
        return {"error": "Schema not found"}
    return schema

@app.post("/schemas/{stream_name}/{event_type}")
async def register_schema(
    stream_name: str,
    event_type: str,
    schema_data: dict
):
    """Register a new schema version"""
    success = await schema_registry.register_schema(
        stream_name=stream_name,
        event_type=event_type,
        schema_version=schema_data["version"],
        schema_definition=schema_data["schema"],
        compatibility=SchemaCompatibility(schema_data.get("compatibility", "backward"))
    )
    return {"success": success}

@app.get("/dlq/{stream_name}")
async def get_dlq_events(stream_name: str, count: int = 100):
    """Get failed events from dead letter queue"""
    events = await dead_letter_queue.get_failed_events(stream_name, count)
    return {"events": events}

@app.post("/dlq/{stream_name}/retry/{message_id}")
async def retry_dlq_event(stream_name: str, message_id: str):
    """Retry a failed event"""
    success, new_msg_id, error = await dead_letter_queue.retry_event(
        stream_name,
        message_id,
        validation_middleware
    )
    return {
        "success": success,
        "new_message_id": new_msg_id,
        "error": error
    }

@app.get("/dlq/stats")
async def get_dlq_stats(stream_name: str = None):
    """Get dead letter queue statistics"""
    stats = await dead_letter_queue.get_dlq_stats(stream_name)
    return stats

@app.get("/validation/stats")
async def get_validation_stats():
    """Get validation middleware statistics"""
    stats = validation_middleware.get_stats()
    return stats
```

---

## Workflow

### 1. Register Schema

```python
# Register initial schema version
await schema_registry.register_schema(
    stream_name="model-events",
    event_type="model-ready",
    schema_version="1.0.0",
    schema_definition={...}
)
```

### 2. Publish Event (with validation)

```python
# Event is automatically validated
success, msg_id, error = await validation_middleware.validate_and_publish(
    "model-events",
    {"event": "model-ready", "model_name": "classifier", "version": "1.0.0"}
)
```

### 3. Handle Invalid Events

```python
# Invalid events automatically go to DLQ
# Query failed events
failed = await dead_letter_queue.get_failed_events("model-events")

# Retry if possible
if failed[0]["can_retry"]:
    await dead_letter_queue.retry_event(
        "model-events",
        failed[0]["dlq_message_id"],
        validation_middleware
    )
```

---

## Benefits

1. **Schema Versioning**: Track schema evolution over time
2. **Validation**: Ensure events conform to schemas before publishing
3. **Error Recovery**: Failed events stored in DLQ for debugging and retry
4. **Observability**: Track validation success rates and failure types
5. **Compatibility**: Check schema compatibility before registering new versions

---

## Next Steps

1. ✅ Schema Registry created
2. ✅ Validation Middleware created
3. ✅ Dead Letter Queue created
4. ✅ Event Publisher updated
5. ⏳ Integrate into main.py
6. ⏳ Add API endpoints
7. ⏳ Add tests
8. ⏳ Add monitoring/alerting for DLQ

