#!/usr/bin/env bash
# Minimal per-service secrets for CI compose config / optional smoke runs.
# Matches ops/k8s/secrets/<service>-secret.yaml layout (gitignored locally).
set -euo pipefail

SECRETS_DIR="$(cd "$(dirname "$0")/../k8s/secrets" && pwd)"
mkdir -p "$SECRETS_DIR"

JWT_SECRET="${JWT_SECRET:-ci-jwt-secret-minimum-32-characters-long}"
INTERNAL_SERVICE_SECRET="${INTERNAL_SERVICE_SECRET:-ci-internal-service-secret}"
REDIS_PASSWORD="${REDIS_PASSWORD:-password}"
INFLUXDB_TOKEN="${INFLUXDB_TOKEN:-ci-influxdb-token-minimum-48-characters-for-validation-xx}"

write_secret() {
  local name="$1"
  local file="$SECRETS_DIR/${name}-secret.yaml"
  cat >"$file" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${name}-secret
  namespace: default
type: Opaque
stringData:
  JWT_SECRET: "${JWT_SECRET}"
  INTERNAL_SERVICE_SECRET: "${INTERNAL_SERVICE_SECRET}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
  INFLUXDB_TOKEN: "${INFLUXDB_TOKEN}"
EOF
}

for svc in \
  api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence \
  external-bridge-service adaptive-experience-engine language-intelligence-service \
  communications-hub messaging-service realtime-gateway synapse frontend-dev cyrex; do
  write_secret "$svc"
done

echo "CI secrets bootstrapped under $SECRETS_DIR"
