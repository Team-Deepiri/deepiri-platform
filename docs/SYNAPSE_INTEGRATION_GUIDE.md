# Synapse Integration Guide

## Overview

**Deepiri Synapse** is the central streaming service that connects all components of the Deepiri architecture through event-driven communication using Redis Streams.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Synapse Service                       │
│              (Central Event Streaming Hub)              │
│                                                          │
│  Streams:                                               │
│  • model-events      (Helox → Cyrex)                    │
│  • inference-events  (Cyrex → Platform)                 │
│  • platform-events  (Platform → AGI)                  │
│  • agi-decisions     (AGI → Platform)                  │
│  • training-events   (Helox → Analytics)                │
└──────────────────┬──────────────────────────────────────┘
                   │
    ┌──────────────┼──────────────┐
    │              │              │
    ▼              ▼              ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│  Helox  │  │  Cyrex  │  │ Platform │
│  (ML)   │  │  (AI)   │  │ Services │
└─────────┘  └─────────┘  └─────────┘
```

## Service Integration Status

### ✅ Fully Integrated Services

All services now have Synapse configuration:

1. **API Gateway** (`api-gateway`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: Route platform events, publish API metrics

2. **Auth Service** (`auth-service`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: Publish authentication events (login, logout, token refresh)

3. **Task Orchestrator** (`task-orchestrator`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: Publish task lifecycle events (created, started, completed, failed)

4. **Engagement Service** (`engagement-service`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: Publish user engagement events (interactions, achievements)

5. **Platform Analytics Service** (`platform-analytics-service`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: **Consume** inference events, training events; aggregate metrics

6. **Notification Service** (`notification-service`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: **Consume** events to trigger notifications

7. **External Bridge Service** (`external-bridge-service`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: Publish external API call events

8. **Challenge Service** (`challenge-service`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`
   - Dependency: `synapse`
   - Use Case: Publish challenge events, consume Cyrex inference events

9. **Realtime Gateway** (`realtime-gateway`)
   - Environment: `SYNAPSE_URL=http://synapse:8002`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
   - Dependency: `redis`, `synapse`
   - Use Case: **Consume** events for real-time WebSocket updates

10. **Cyrex** (`cyrex`)
    - Environment: `SYNAPSE_URL=http://synapse:8002`
    - Dependency: `synapse`
    - Use Case: **Subscribe** to model-ready events, **Publish** inference events

11. **Frontend** (`frontend-dev`)
    - Environment: `VITE_SYNAPSE_URL=http://localhost:8002`
    - Dependency: `synapse`
    - Use Case: Display real-time metrics, stream status

12. **Cyrex Interface** (`cyrex-interface`)
    - Environment: `VITE_SYNAPSE_URL=http://localhost:8002`
    - Dependency: `synapse`
    - Use Case: Display streaming metrics, event logs

## Event Streams

### 1. `model-events`
**Purpose**: Model lifecycle events from Helox to Cyrex

**Publishers**: Helox (ML Training)
**Subscribers**: Cyrex (Runtime)

**Event Types**:
- `model-ready`: New model trained and registered
- `model-updated`: Model version updated
- `model-deprecated`: Model marked as deprecated

**Example Event**:
```json
{
  "event_type": "model-ready",
  "model_name": "task-classifier-v2",
  "version": "2.0.0",
  "registry_path": "s3://mlflow-artifacts/models/task-classifier-v2",
  "metadata": {
    "accuracy": 0.95,
    "training_time": "2h 30m"
  }
}
```

### 2. `inference-events`
**Purpose**: Real-time inference metrics from Cyrex

**Publishers**: Cyrex (Runtime)
**Subscribers**: Platform Analytics, Notification Service, Realtime Gateway

**Event Types**:
- `inference-complete`: Inference finished with metrics
- `inference-error`: Inference failed
- `model-loaded`: Model successfully loaded in Cyrex

**Example Event**:
```json
{
  "event_type": "inference-complete",
  "request_id": "req_123456",
  "model_name": "task-classifier-v2",
  "latency_ms": 45,
  "confidence": 0.92,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 3. `platform-events`
**Purpose**: Platform-wide events (user actions, system events)

**Publishers**: All Platform Services
**Subscribers**: Cyrex-AGI (future), Analytics Service

**Event Types**:
- `user-action`: User performed an action
- `system-event`: System-level event
- `service-status`: Service health change

### 4. `agi-decisions`
**Purpose**: Autonomous decisions from Cyrex-AGI (Phase 5)

**Publishers**: Cyrex-AGI
**Subscribers**: Platform Services, Cyrex

**Event Types**:
- `decision-made`: AGI made an autonomous decision
- `action-taken`: AGI executed an action
- `self-improvement`: AGI initiated self-improvement

### 5. `training-events`
**Purpose**: Training progress and metrics from Helox

**Publishers**: Helox (ML Training)
**Subscribers**: Platform Analytics, Monitoring

**Event Types**:
- `training-started`: Training job started
- `training-progress`: Epoch/step progress
- `training-complete`: Training finished
- `training-failed`: Training error

## Integration Patterns

### Publishing Events

**Using deepiri-modelkit (Python)**:
```python
from deepiri_modelkit.streaming import StreamingClient
from deepiri_modelkit.contracts.events import InferenceEvent

# Initialize client
client = StreamingClient(
    redis_host="redis",
    redis_port=6379,
    redis_password="redispassword"
)
await client.connect()

# Publish event
event = InferenceEvent(
    event_type="inference-complete",
    request_id="req_123",
    model_name="task-classifier-v2",
    latency_ms=45,
    confidence=0.92
)

await client.publish("inference-events", event.dict())
```

**Using HTTP API (Node.js/TypeScript)**:
```typescript
import axios from 'axios';

const synapseUrl = process.env.SYNAPSE_URL || 'http://synapse:8002';

// Publish event via Synapse API (if implemented)
await axios.post(`${synapseUrl}/events/inference-events`, {
  event_type: 'inference-complete',
  request_id: 'req_123',
  model_name: 'task-classifier-v2',
  latency_ms: 45,
  confidence: 0.92
});
```

### Subscribing to Events

**Using deepiri-modelkit (Python)**:
```python
from deepiri_modelkit.streaming import StreamingClient

client = StreamingClient(
    redis_host="redis",
    redis_port=6379,
    redis_password="redispassword"
)
await client.connect()

# Subscribe with callback
async def handle_inference_event(event: dict):
    print(f"Inference completed: {event['request_id']}")
    # Process event...

async for event in client.subscribe(
    "inference-events",
    callback=handle_inference_event,
    consumer_group="analytics-service",
    consumer_name="analytics-1"
):
    # Process event...
    pass
```

## Configuration

### Environment Variables

All services should have:
```bash
SYNAPSE_URL=http://synapse:8002
```

For frontend services:
```bash
VITE_SYNAPSE_URL=http://localhost:8002
```

### Docker Compose Dependencies

Services that use Synapse should include:
```yaml
depends_on:
  - synapse
```

## Monitoring

### Synapse Health Check
```bash
curl http://localhost:8002/health
```

### List All Streams
```bash
curl http://localhost:8002/streams
```

### Get Stream Info
```bash
curl http://localhost:8002/streams/inference-events/info
```

### Get Recent Messages
```bash
curl http://localhost:8002/streams/inference-events/messages?count=10
```

### Get Metrics
```bash
curl http://localhost:8002/metrics
```

## Next Steps

1. **Implement Event Publishers**: Add event publishing to each service
2. **Implement Event Consumers**: Add event subscription logic
3. **Add Event Schemas**: Define Pydantic models for all event types
4. **Add Monitoring**: Dashboard for stream health and metrics
5. **Add Error Handling**: Retry logic, dead letter queues
6. **Add Testing**: Integration tests for event flows

## Resources

- **Synapse Service**: `platform-services/shared/deepiri-synapse`
- **ModelKit Streaming Client**: `deepiri-modelkit/src/deepiri_modelkit/streaming`
- **Event Contracts**: `deepiri-modelkit/src/deepiri_modelkit/contracts/events.py`
- **Stream Topics**: `deepiri-modelkit/src/deepiri_modelkit/streaming/topics.py`

