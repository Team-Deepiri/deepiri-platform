# Deepiri Synapse - Central Streaming Service

**Purpose**: Central event streaming service for all Deepiri services

## Architecture

Synapse acts as the nervous system connecting:
- Helox (ML training) → Cyrex (runtime)
- Cyrex → Platform Services
- Platform Services → Cyrex-AGI
- Cyrex-AGI → Platform Services

## Streams

- `model-events`: Model training and deployment
- `inference-events`: AI inference metrics
- `platform-events`: Platform service events
- `agi-decisions`: AGI autonomous decisions
- `training-events`: Training progress

## Usage

All services use `deepiri-modelkit` streaming client to interact with Synapse.

## Related

- `deepiri-modelkit`: Streaming client library
- All platform services: Publish/consume events

