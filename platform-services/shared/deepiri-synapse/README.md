# Deepiri Synapse

**Event streaming and messaging service for Deepiri platform.**

## What is Synapse?

Synapse is the **nervous system** of the Deepiri platform - a high-performance event streaming service that enables real-time communication between all microservices. It provides:

- **Event Streaming** - Publish/subscribe messaging for cross-service communication
- **Message Queuing** - Reliable message delivery with persistence
- **Event Routing** - Intelligent routing based on event types and patterns
- **Service Discovery** - Automatic service registration and discovery
- **Event History** - Replay capabilities for debugging and recovery

### Core Purpose

Synapse serves as the **event bus** that connects:
- **Helox** (ML Training) - Publishes model-ready events
- **Cyrex** (Runtime) - Subscribes to model events, publishes inference events
- **Platform Services** - Consume and publish platform events
- **Cyrex-AGI** (Future) - AGI decision events and coordination

### Architecture

```
┌─────────────────────────────────────────┐
│         SYNAPSE SERVICE                 │
│                                         │
│  • Redis Streams / Kafka Backend       │
│  • Event Routing & Filtering            │
│  • Message Persistence                  │
│  • Service Registry                     │
│  • Event Replay & History               │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐
│ Helox  │ │ Cyrex   │ │Platform│
│        │ │         │ │Services│
└────────┘ └────────┘ └────────┘
```

### Key Features

1. **High Throughput** - Handles thousands of events per second
2. **Reliability** - Message persistence and guaranteed delivery
3. **Scalability** - Horizontal scaling with Redis Cluster or Kafka
4. **Event Filtering** - Subscribe to specific event types or patterns
5. **Replay Capability** - Replay events for debugging or recovery
6. **Service Discovery** - Automatic registration of services

### Event Topics

- `model-events` - Model lifecycle (ready, updated, deprecated)
- `inference-events` - Model predictions and results
- `training-events` - Training progress and completion
- `platform-events` - General platform notifications
- `agi-decisions` - AGI system decisions and actions
- `error-events` - Error tracking and alerting

### Technology Stack

- **Backend**: Redis Streams (primary) or Apache Kafka (enterprise)
- **Protocol**: Redis Streams API or Kafka Protocol
- **Persistence**: Redis AOF/RDB or Kafka log retention
- **Monitoring**: Prometheus metrics, Grafana dashboards

### Use Cases

1. **Model Deployment** - Helox publishes model-ready → Cyrex auto-loads
2. **Real-time Updates** - Platform services publish events → Frontend subscribes
3. **Event Sourcing** - All events stored for audit and replay
4. **Service Coordination** - Services discover and communicate via events
5. **Error Propagation** - Errors published → Monitoring services alerted

### Integration

Synapse integrates with:
- **ModelKit** - Uses ModelKit event schemas (`ModelReadyEvent`, `InferenceEvent`)
- **Redis** - Primary backend for event streaming
- **Kafka** - Enterprise backend option for high-scale deployments
- **Platform Services** - All services publish/subscribe via Synapse

### Why "Synapse"?

Just like biological synapses connect neurons in the brain, **Synapse connects services** in the Deepiri platform, enabling rapid, reliable communication and coordination.

---

## Installation & Setup

### Prerequisites

- Python 3.11+
- Redis 7.0+ (running locally or accessible)
- pip

### Install Dependencies

```bash
# Install required packages
pip install -r requirements.txt

# Or install individually
pip install fastapi uvicorn redis pydantic pytest pytest-asyncio
```

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio

# Run all tests
pytest tests/

# Run with verbose output
pytest tests/ -v

# Run specific test file
pytest tests/test_schema_registry.py

# Run with coverage
pytest tests/ --cov=app --cov-report=html
```

### Running the Service

```bash
# Set environment variables
export REDIS_HOST=localhost
export REDIS_PORT=6379
export REDIS_PASSWORD=your_password

# Run with uvicorn
uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
```

### Docker Setup

```bash
# Build Docker image
docker build -t deepiri-synapse .

# Run with docker-compose (from platform root)
docker compose up synapse
```

### Environment Variables

- `REDIS_HOST` - Redis host (default: `redis`)
- `REDIS_PORT` - Redis port (default: `6379`)
- `REDIS_PASSWORD` - Redis password (default: `redispassword`)

---

## Development

### Project Structure

```
deepiri-synapse/
├── app/
│   ├── schemas/          # Schema registry and validators
│   ├── middleware/       # Validation middleware
│   ├── streams/          # Stream manager and DLQ
│   ├── producers/        # Event publishers
│   ├── consumers/        # Event consumers
│   └── monitoring/       # Metrics collection
├── tests/                # Test suite
├── requirements.txt      # Python dependencies
└── README.md            # This file
```

### Running Tests

See [tests/README.md](tests/README.md) for detailed test instructions.

**Quick Start:**
```bash
# Install dependencies first
pip install -r requirements.txt pytest pytest-asyncio

# Run tests
pytest tests/ -v
```

### Code Quality

```bash
# Run linter (if configured)
flake8 app/
black app/ --check

# Type checking (if configured)
mypy app/
```

---

## API Endpoints

- `GET /health` - Health check
- `GET /streams` - List all streams
- `GET /streams/{stream_name}/info` - Stream information
- `GET /streams/{stream_name}/messages` - Recent messages
- `GET /metrics` - Service metrics

See [SCHEMA_REGISTRY_INTEGRATION.md](SCHEMA_REGISTRY_INTEGRATION.md) for additional endpoints.

---

## Documentation

- [Schema Registry Integration](app/schemas/SCHEMA_REGISTRY_INTEGRATION.md)
- [Test Explanation](tests/TEST_EXPLANATION.md)
- [Architecture](ARCHITECTURE.md)

