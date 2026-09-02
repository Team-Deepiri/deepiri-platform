# ConfigMaps by plane

## Cloud portal (`docker-compose.yml`) — **use these on deepiri-platform**

| ConfigMap | Service |
|-----------|---------|
| `api-gateway-configmap.yaml` | Slim gateway (`CLOUD_PORTAL_MODE=true`) |
| `auth-service-configmap.yaml` | Auth → `postgres-platform` / `platform` DB |
| `registry-configmap.yaml` | Registry |
| `jobs-configmap.yaml` | Jobs + `platform.pg_backup` |
| `external-bridge-service-configmap.yaml` | Plaky poll, no Kafka |
| `platform-frontend-configmap.yaml` | Portal UI build flags |

## Control plane only — **use from deepiri-control-plane repo**

These files remain in-tree for reference during the repo split. They target Cyrex/LIS/speech/messaging and are **not** part of the cloud VPS stack:

`cyrex-configmap.yaml`, `cyrex-agi-configmap.yaml`, `language-intelligence-service-configmap.yaml`, `speech-configmap.yaml`, `messaging-service-configmap.yaml`, `realtime-gateway-configmap.yaml`, `telemetry-configmap.yaml`, `truss-configmap.yaml`, `synapse-configmap.yaml`, `mlflow-configmap.yaml`, `frontend-dev-configmap.yaml`

Deployments `cyrex-deployment.yaml`, `localai-deployment.yaml`, `backend-deployment.yaml` (legacy monolith) are likewise control-plane / legacy.
