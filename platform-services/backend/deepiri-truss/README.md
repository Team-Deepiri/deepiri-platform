# Deepiri Truss

DB-backed workflow orchestration for platform jobs and service-to-service workflows.

## Responsibilities

- Store immutable Truss workflow definitions.
- Create and track workflow runs.
- Execute Phase 1 step kinds:
  - `jobStep`: submit a job to `deepiri-jobs` and reconcile from the real job status.
  - `conditionStep`: evaluate a structured comparison against run context.
  - `waitEventStep`: mark the run waiting for a future event correlation pass.
- Auto-provision the `ml.train-publish` template from `templates/ml.train-publish.yaml` on first use.

## Endpoints

- `GET /api/truss/definitions`
- `GET /api/truss/definitions?allVersions=true`
- `POST /api/truss/definitions`
- `GET /api/truss/definitions/:id`
- `POST /api/truss/definitions/:id/runs`
- `POST /api/truss/templates/ml.train-publish`
- `GET /api/truss/runs`
- `GET /api/truss/runs/:id`
- `GET /api/truss/runs/:id/steps`
- `POST /api/truss/runs/:id/cancel`

The router is also mounted at `/` so the service works whether the gateway preserves or strips the `/api/truss` prefix.

## Template Versioning

Definitions are immutable once materialized. When `POST /api/truss/templates/ml.train-publish` is called, Truss parses the YAML template and compares the normalized step list against the latest `ml.train-publish` definition. If the steps changed, Truss creates a new definition with the next version number. Existing runs continue to point at the exact definition version they executed.

## Configuration

- `DATABASE_URL`: PostgreSQL connection string.
- `JOBS_URL`: base URL for `deepiri-jobs`, used by `jobStep`.
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`: Redis Streams connection for platform event publishing.

## Phase 1 Limitations

`waitEventStep` is intentionally honest: it leaves the run in `waiting` state and records the event criteria. Redis/Synapse event correlation is a later implementation step.
