#!/usr/bin/env bash

# Stack watchdog:
# - checks compose container state/health
# - checks key HTTP endpoints (/health, /readyz) where applicable
# - restarts only missing/unhealthy/failed services

set -uo pipefail

COMPOSE_FILE="docker-compose.rtg-sugar-glider.local.yml"
INTERVAL_SEC=60
HTTP_TIMEOUT_SEC=3
RUN_ONCE=false
QUIET=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

log() {
    if [ "${QUIET}" = true ]; then
        return
    fi
    printf '%s %s\n' "[$(date '+%Y-%m-%d %H:%M:%S')]" "$*"
}

usage() {
    cat <<'EOF'
Usage: stack_watchdog.sh [options]

Options:
  -f, --file <compose-file>     Docker compose file (default: docker-compose.rtg-sugar-glider.local.yml)
  -i, --interval <seconds>      Loop interval in seconds (default: 60)
  -t, --timeout <seconds>       HTTP timeout for endpoint checks (default: 3)
      --once                    Run one pass and exit
  -q, --quiet                   Suppress informational logs
  -h, --help                    Show this help

Examples:
  ./scripts/dev/sugarglider/stack_watchdog.sh --once
  ./scripts/dev/sugarglider/stack_watchdog.sh --interval 30
  ./scripts/dev/sugarglider/stack_watchdog.sh --file docker-compose.dev.yml --once
EOF
}

require_bin() {
    local bin="$1"
    if ! command -v "${bin}" >/dev/null 2>&1; then
        echo "Missing required command: ${bin}" >&2
        exit 1
    fi
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -f|--file)
                COMPOSE_FILE="${2:-}"
                shift 2
                ;;
            -i|--interval)
                INTERVAL_SEC="${2:-}"
                shift 2
                ;;
            -t|--timeout)
                HTTP_TIMEOUT_SEC="${2:-}"
                shift 2
                ;;
            --once)
                RUN_ONCE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
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

get_services() {
    docker compose -f "${COMPOSE_FILE}" ps --services 2>/dev/null || true
}

restart_service() {
    local service="$1"
    log "Healing service '${service}'"
    docker compose -f "${COMPOSE_FILE}" restart "${service}" >/dev/null 2>&1 || \
        docker compose -f "${COMPOSE_FILE}" up -d "${service}" >/dev/null
}

check_http_endpoint() {
    local url="$1"
    curl -fsS --max-time "${HTTP_TIMEOUT_SEC}" "${url}" >/dev/null 2>&1
}

endpoint_for_service() {
    case "$1" in
        synapse)
            echo "http://localhost:8002/health"
            ;;
        realtime-gateway)
            echo "http://localhost:5008/health"
            ;;
        synapse-sugar-glider)
            echo "http://localhost:8081/readyz"
            ;;
        synapse-sidecar)
            echo "http://localhost:8081/readyz"
            ;;
        *)
            echo ""
            ;;
    esac
}

check_service() {
    local service="$1"
    local cid state health endpoint

    cid="$(docker compose -f "${COMPOSE_FILE}" ps -q "${service}" 2>/dev/null || true)"
    if [ -z "${cid}" ]; then
        log "Service '${service}' has no container (missing)"
        restart_service "${service}"
        ACTIONS=$((ACTIONS + 1))
        return
    fi

    state="$(docker inspect -f '{{.State.Status}}' "${cid}" 2>/dev/null || echo unknown)"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${cid}" 2>/dev/null || echo unknown)"

    if [ "${state}" != "running" ] || [ "${health}" = "unhealthy" ]; then
        log "Service '${service}' unhealthy (state=${state}, health=${health})"
        restart_service "${service}"
        ACTIONS=$((ACTIONS + 1))
        return
    fi

    endpoint="$(endpoint_for_service "${service}")"
    if [ -n "${endpoint}" ] && ! check_http_endpoint "${endpoint}"; then
        log "Service '${service}' endpoint check failed (${endpoint})"
        restart_service "${service}"
        ACTIONS=$((ACTIONS + 1))
    fi
}

run_pass() {
    ACTIONS=0
    local services
    services="$(get_services)"
    if [ -z "${services}" ]; then
        log "No running services found for compose file '${COMPOSE_FILE}'"
        return
    fi

    for service in ${services}; do
        check_service "${service}"
    done

    if [ "${ACTIONS}" -eq 0 ]; then
        log "Watchdog pass complete: no healing actions needed"
    else
        log "Watchdog pass complete: applied ${ACTIONS} healing action(s)"
    fi
}

main() {
    parse_args "$@"

    if ! is_positive_integer "${INTERVAL_SEC}"; then
        echo "Invalid --interval value: ${INTERVAL_SEC}" >&2
        exit 1
    fi
    if ! is_positive_integer "${HTTP_TIMEOUT_SEC}"; then
        echo "Invalid --timeout value: ${HTTP_TIMEOUT_SEC}" >&2
        exit 1
    fi

    require_bin docker
    require_bin curl

    if ! docker info >/dev/null 2>&1; then
        echo "Docker is not running. Start Docker Desktop and retry." >&2
        exit 1
    fi

    cd "${REPO_ROOT}"
    log "Starting stack watchdog (file=${COMPOSE_FILE}, interval=${INTERVAL_SEC}s, once=${RUN_ONCE})"

    while true; do
        run_pass
        if [ "${RUN_ONCE}" = true ]; then
            break
        fi
        sleep "${INTERVAL_SEC}"
    done
}

main "$@"
