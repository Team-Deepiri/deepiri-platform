#!/usr/bin/env bash

# Sidecar failure-path test:
# 1) Simulate Redis outage and verify publish queues to WAL
# 2) Restore Redis and verify WAL replay back to stream
# 3) Inject high-retry pending message and verify DLQ move

set -euo pipefail

COMPOSE_FILE="docker-compose.rtg-sidecar.local.yml"
SIDECAR_URL="http://localhost:8081"
REDIS_SERVICE="redis"
REDIS_PASSWORD="redispassword"
STREAM="platform-events"
DLQ_GROUP="sidecar-dlq-chaos"
DLQ_CONSUMER="sidecar-dlq-chaos-consumer"
WAL_TIMEOUT_SEC=120
DLQ_TIMEOUT_SEC=40
HTTP_TIMEOUT_SEC=8

REDIS_STOPPED=0

usage() {
    cat <<'EOF'
Usage: sidecar_failure_test.sh [options]

Options:
  --file <compose-file>          Compose file (default: docker-compose.rtg-sidecar.local.yml)
  --url <sidecar-url>            Sidecar URL (default: http://localhost:8081)
  --redis-service <name>         Redis service name in compose (default: redis)
  --redis-password <password>    Redis password (default: redispassword)
  --stream <name>                Stream to test (default: platform-events)
  --wal-timeout-sec <sec>        Timeout waiting for WAL replay (default: 120)
  --dlq-timeout-sec <sec>        Timeout waiting for DLQ move (default: 40)
  -h, --help                     Show help
EOF
}

log() {
    printf '%s\n' "$*"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_bin() {
    local bin="$1"
    command -v "${bin}" >/dev/null 2>&1 || fail "Missing required command: ${bin}"
}

is_positive_integer() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            [ "$1" -gt 0 ]
            ;;
    esac
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --file)
                COMPOSE_FILE="${2:-}"
                shift 2
                ;;
            --url)
                SIDECAR_URL="${2:-}"
                shift 2
                ;;
            --redis-service)
                REDIS_SERVICE="${2:-}"
                shift 2
                ;;
            --redis-password)
                REDIS_PASSWORD="${2:-}"
                shift 2
                ;;
            --stream)
                STREAM="${2:-}"
                shift 2
                ;;
            --wal-timeout-sec)
                WAL_TIMEOUT_SEC="${2:-}"
                shift 2
                ;;
            --dlq-timeout-sec)
                DLQ_TIMEOUT_SEC="${2:-}"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
}

dc() {
    docker compose -f "${COMPOSE_FILE}" "$@"
}

redis_cmd() {
    dc exec -T "${REDIS_SERVICE}" redis-cli -a "${REDIS_PASSWORD}" "$@"
}

wait_for_redis() {
    local max_tries=30
    local i
    for i in $(seq 1 "${max_tries}"); do
        if redis_cmd ping >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

sidecar_config() {
    curl -fsS --max-time "${HTTP_TIMEOUT_SEC}" "${SIDECAR_URL}/v1/config"
}

stream_contains() {
    local stream_name="$1"
    local needle="$2"
    redis_cmd --raw XREVRANGE "${stream_name}" + - COUNT 300 2>/dev/null | grep -q "${needle}"
}

cleanup() {
    if [ "${REDIS_STOPPED}" -eq 1 ]; then
        log "Cleanup: bringing Redis back up"
        dc up -d "${REDIS_SERVICE}" >/dev/null 2>&1 || true
        REDIS_STOPPED=0
    fi
}

main() {
    parse_args "$@"

    is_positive_integer "${WAL_TIMEOUT_SEC}" || fail "Invalid --wal-timeout-sec"
    is_positive_integer "${DLQ_TIMEOUT_SEC}" || fail "Invalid --dlq-timeout-sec"

    require_bin docker
    require_bin curl
    require_bin jq

    trap cleanup EXIT

    docker info >/dev/null 2>&1 || fail "Docker daemon is not running"
    dc ps >/dev/null 2>&1 || fail "Compose file not usable: ${COMPOSE_FILE}"

    log "Step 1/3: Checking sidecar readiness"
    local ready
    ready="$(curl -fsS --max-time "${HTTP_TIMEOUT_SEC}" "${SIDECAR_URL}/readyz" 2>/dev/null || true)"
    echo "${ready}" | jq -e '.ready == true' >/dev/null 2>&1 || fail "Sidecar is not ready at ${SIDECAR_URL}"

    wait_for_redis || fail "Redis is not reachable before starting failure-path test"

    local wal_smoke_id wal_before wal_after publish_body publish_resp publish_status publish_json
    wal_smoke_id="wal-smoke-$(date +%s)-${RANDOM}"

    wal_before="$(sidecar_config | jq -r '.metrics.wal_replayed // 0')"
    log "Step 2/3: Simulating Redis outage and validating WAL replay (smoke_id=${wal_smoke_id})"

    dc stop "${REDIS_SERVICE}" >/dev/null
    REDIS_STOPPED=1
    sleep 2

    publish_body="$(jq -cn \
        --arg stream "${STREAM}" \
        --arg event_type "chaos.wal.test" \
        --arg sender "sidecar-failure-test" \
        --arg smoke_id "${wal_smoke_id}" \
        '{stream: $stream, event_type: $event_type, sender: $sender, priority: "normal", payload: {smoke_id: $smoke_id, mode: "redis_outage"}}')"

    publish_json="$(mktemp)"
    publish_status="$(curl -sS -o "${publish_json}" -w '%{http_code}' --max-time "${HTTP_TIMEOUT_SEC}" -X POST "${SIDECAR_URL}/v1/publish" -H 'Content-Type: application/json' -d "${publish_body}" || true)"
    publish_resp="$(cat "${publish_json}")"
    rm -f "${publish_json}"

    [ "${publish_status}" = "503" ] || fail "Expected queued 503 response during outage, got ${publish_status} with body: ${publish_resp}"
    echo "${publish_resp}" | jq -e '.queued == true' >/dev/null 2>&1 || fail "Expected queued=true during outage, body: ${publish_resp}"

    dc up -d "${REDIS_SERVICE}" >/dev/null
    REDIS_STOPPED=0
    wait_for_redis || fail "Redis did not recover after restart"

    local elapsed wal_depth
    elapsed=0
    while [ "${elapsed}" -lt "${WAL_TIMEOUT_SEC}" ]; do
        wal_depth="$(sidecar_config | jq -r '.wal_depth // -1')"
        if [ "${wal_depth}" = "0" ] && stream_contains "${STREAM}" "${wal_smoke_id}"; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    [ "${elapsed}" -lt "${WAL_TIMEOUT_SEC}" ] || fail "Timed out waiting for WAL replay verification"
    wal_after="$(sidecar_config | jq -r '.metrics.wal_replayed // 0')"
    [ "${wal_after}" -ge "${wal_before}" ] || fail "WAL replay metric regressed unexpectedly"
    log "PASS: WAL failure-path validated (queued during outage, replayed after recovery)"

    log "Step 3/3: Validating DLQ move for over-retried pending entry"
    local dlq_smoke_id dlq_payload dlq_entry_id
    dlq_smoke_id="dlq-smoke-$(date +%s)-${RANDOM}"
    dlq_payload="smoke_id:${dlq_smoke_id}"

    dlq_entry_id="$(redis_cmd XADD "${STREAM}" '*' event_type "chaos.dlq.test" sender "sidecar-failure-test" priority "normal" payload "${dlq_payload}" timestamp "$(date -u +%FT%TZ)" | tail -n1 | tr -d '\r')"
    [ -n "${dlq_entry_id}" ] || fail "Failed to create DLQ test stream entry"

    redis_cmd XGROUP CREATE "${STREAM}" "${DLQ_GROUP}" 0 MKSTREAM >/dev/null 2>&1 || true

    # Create/overwrite pending metadata with high retry count and idle time above threshold.
    redis_cmd XCLAIM "${STREAM}" "${DLQ_GROUP}" "${DLQ_CONSUMER}" 0 "${dlq_entry_id}" IDLE 31000 RETRYCOUNT 3 FORCE JUSTID >/dev/null

    elapsed=0
    while [ "${elapsed}" -lt "${DLQ_TIMEOUT_SEC}" ]; do
        if stream_contains "${STREAM}:dlq" "${dlq_smoke_id}"; then
            log "PASS: DLQ failure-path validated (entry moved to ${STREAM}:dlq)"
            log "All failure-path checks passed."
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    fail "Timed out waiting for DLQ move (smoke_id=${dlq_smoke_id})"
}

main "$@"
