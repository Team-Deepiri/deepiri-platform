# Platform Services Repurpose Plan

Team-Deepiri platform data plane: registry, telemetry, jobs, truss, messaging.

## Service map

| Legacy | New | Port |
|--------|-----|------|
| workflow-orchestrator | **truss** | 5002 |
| incentive-engine | **registry** | 5003 |
| decision-intelligence | **telemetry** | 5004 |
| adaptive-experience-engine | **jobs** | 5007 |
| communications-hub | **messaging-service** | 5009 |

## Environment (k8s configmaps + per-service secrets)

- **Config**: `ops/k8s/configmaps/<service>-configmap.yaml` (committed)
- **Secrets**: `ops/k8s/secrets/<service>-secret.yaml` (local, untracked — duplicate shared keys per file)
- **Loader**: `K8S_SERVICE_NAME` loads one configmap + one secret YAML at container start

No hand-maintained `.env.example` as source of truth.

## Gateway routes

| Route | Service |
|-------|---------|
| `/api/truss` | truss |
| `/api/registry` | registry |
| `/api/jobs` | jobs |
| `/api/telemetry` | telemetry |
| `/api/notifications` | messaging |
| `/api/tasks` | truss (legacy alias) |
| `/api/analytics` | telemetry (legacy alias) |

## ML training path

`deepiri-jobs` `helox.train` → `POST /training/runs` on **diri-helox** → `deepiri-training-orchestrator` in-process → Synapse `training.*`

## PR stack (platform)

1. Phase 0 dead code
2. Renames + compose/k8s
3. Messaging absorbs comms-hub
4. Registry catalog
5. Jobs / Truss / Telemetry repurpose
6. Docs (this file)
7. Submodule pointer bumps
8. Legacy alias cleanup
