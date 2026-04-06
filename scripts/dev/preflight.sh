#!/usr/bin/env bash

# Preflight checks for local stack startup.
# Focused on fast, actionable checks to avoid wasted startup time.

set -uo pipefail

COMPOSE_FILE="docker-compose.rtg-sidecar.local.yml"
MIN_DISK_GB=10
MIN_MEM_GB=4
HTTP_TIMEOUT_SEC=3
REQUIRE_ENDPOINTS=false
QUIET=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FAILURES=0
WARNINGS=0

usage() {
    cat <<'EOF'
Usage: preflight.sh [options]

Options:
  -f, --file <compose-file>     Compose file to validate (default: docker-compose.rtg-sidecar.local.yml)
      --min-disk-gb <gb>        Minimum free disk required at repo root (default: 10)
      --min-mem-gb <gb>         Minimum available memory required (default: 4)
      --timeout <seconds>       HTTP timeout for endpoint probes (default: 3)
      --require-endpoints       Fail if HTTP endpoints are unreachable
  -q, --quiet                   Minimal output
  -h, --help                    Show this help

Examples:
  ./scripts/dev/preflight.sh
  ./scripts/dev/preflight.sh --file docker-compose.dev.yml
  ./scripts/dev/preflight.sh --require-endpoints
EOF
}

log() {
    if [ "${QUIET}" = true ]; then
        return
    fi
    printf '%s\n' "$*"
}

pass() {
    log "PASS: $*"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    log "WARN: $*"
}

fail() {
    FAILURES=$((FAILURES + 1))
    log "FAIL: $*"
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -f|--file)
                COMPOSE_FILE="${2:-}"
                shift 2
                ;;
            --min-disk-gb)
                MIN_DISK_GB="${2:-}"
                shift 2
                ;;
            --min-mem-gb)
                MIN_MEM_GB="${2:-}"
                shift 2
                ;;
            --timeout)
                HTTP_TIMEOUT_SEC="${2:-}"
                shift 2
                ;;
            --require-endpoints)
                REQUIRE_ENDPOINTS=true
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

require_bin() {
    local bin="$1"
    if command -v "${bin}" >/dev/null 2>&1; then
        pass "Found command '${bin}'"
    else
        fail "Missing command '${bin}'"
    fi
}

check_docker_daemon() {
    if ! command -v docker >/dev/null 2>&1; then
        fail "Docker CLI not found"
        return
    fi
    if docker info >/dev/null 2>&1; then
        pass "Docker daemon is running"
    else
        fail "Docker daemon is not running (start Docker Desktop)"
    fi
}

check_compose_file() {
    if [ ! -f "${COMPOSE_FILE}" ]; then
        fail "Compose file not found: ${COMPOSE_FILE}"
        return
    fi
    if docker compose -f "${COMPOSE_FILE}" config >/dev/null 2>&1; then
        pass "Compose file validates: ${COMPOSE_FILE}"
    else
        fail "Compose file failed validation: ${COMPOSE_FILE}"
    fi
}

stack_has_running_services() {
    local services svc cid state
    services="$(docker compose -f "${COMPOSE_FILE}" ps --services 2>/dev/null || true)"
    for svc in ${services}; do
        cid="$(docker compose -f "${COMPOSE_FILE}" ps -q "${svc}" 2>/dev/null || true)"
        if [ -z "${cid}" ]; then
            continue
        fi
        state="$(docker inspect -f '{{.State.Status}}' "${cid}" 2>/dev/null || echo unknown)"
        if [ "${state}" = "running" ]; then
            return 0
        fi
    done
    return 1
}

service_is_running() {
    local service="$1"
    local cid state
    cid="$(docker compose -f "${COMPOSE_FILE}" ps -q "${service}" 2>/dev/null || true)"
    if [ -z "${cid}" ]; then
        return 1
    fi
    state="$(docker inspect -f '{{.State.Status}}' "${cid}" 2>/dev/null || echo unknown)"
    [ "${state}" = "running" ]
}

check_port_conflicts() {
    local ports port listeners running_stack
    ports="6379 8002 5008 8081"

    if ! command -v lsof >/dev/null 2>&1; then
        warn "lsof not found; skipping port conflict checks"
        return
    fi

    if stack_has_running_services; then
        running_stack=true
    else
        running_stack=false
    fi

    for port in ${ports}; do
        listeners="$(lsof -nP -iTCP:${port} -sTCP:LISTEN 2>/dev/null || true)"
        if [ -z "${listeners}" ]; then
            pass "Port ${port} is available"
            continue
        fi

        if [ "${running_stack}" = true ]; then
            warn "Port ${port} is in use (acceptable if stack is already running)"
        else
            fail "Port ${port} is in use before startup"
        fi
    done
}

check_disk() {
    local avail_kb avail_gb
    avail_kb="$(df -Pk "${REPO_ROOT}" | awk 'END {print $4}')"
    if [ -z "${avail_kb}" ]; then
        warn "Unable to determine free disk space"
        return
    fi
    avail_gb=$((avail_kb / 1024 / 1024))
    if [ "${avail_gb}" -lt "${MIN_DISK_GB}" ]; then
        fail "Low disk space: ${avail_gb}GB free (< ${MIN_DISK_GB}GB required)"
    else
        pass "Disk space OK: ${avail_gb}GB free"
    fi
}

get_available_mem_gb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemAvailable/ {printf "%.0f", $2/1024/1024; exit}' /proc/meminfo
        return
    fi

    if command -v vm_stat >/dev/null 2>&1; then
        local vmout pagesize free inactive speculative total_pages
        vmout="$(vm_stat 2>/dev/null || true)"
        if [ -z "${vmout}" ]; then
            echo ""
            return
        fi
        pagesize="$(echo "${vmout}" | awk -F'page size of | bytes' 'NR==1 {print $2}')"
        pagesize="${pagesize:-4096}"
        free="$(echo "${vmout}" | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
        inactive="$(echo "${vmout}" | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
        speculative="$(echo "${vmout}" | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')"
        free="${free:-0}"
        inactive="${inactive:-0}"
        speculative="${speculative:-0}"
        total_pages=$((free + inactive + speculative))
        echo $((total_pages * pagesize / 1024 / 1024 / 1024))
        return
    fi

    echo ""
}

check_memory() {
    local avail_gb
    avail_gb="$(get_available_mem_gb)"
    if [ -z "${avail_gb}" ]; then
        warn "Unable to determine available memory"
        return
    fi
    if [ "${avail_gb}" -lt "${MIN_MEM_GB}" ]; then
        fail "Low available memory: ${avail_gb}GB (< ${MIN_MEM_GB}GB required)"
    else
        pass "Memory OK: ${avail_gb}GB available"
    fi
}

check_endpoint() {
    local service="$1"
    local url="$2"
    local required="$3"

    if curl -fsS --max-time "${HTTP_TIMEOUT_SEC}" "${url}" >/dev/null 2>&1; then
        pass "${service} endpoint reachable: ${url}"
        return
    fi

    if [ "${required}" = true ]; then
        fail "${service} endpoint unreachable: ${url}"
    else
        warn "${service} endpoint unreachable: ${url} (ok if stack not started yet)"
    fi
}

check_endpoints() {
    local synapse_required gateway_required sidecar_required

    synapse_required=false
    gateway_required=false
    sidecar_required=false

    if [ "${REQUIRE_ENDPOINTS}" = true ]; then
        synapse_required=true
        gateway_required=true
        sidecar_required=true
    else
        service_is_running "synapse" && synapse_required=true
        service_is_running "realtime-gateway" && gateway_required=true
        service_is_running "synapse-sidecar" && sidecar_required=true
    fi

    check_endpoint "synapse" "http://localhost:8002/health" "${synapse_required}"
    check_endpoint "realtime-gateway" "http://localhost:5008/health" "${gateway_required}"
    check_endpoint "synapse-sidecar" "http://localhost:8081/readyz" "${sidecar_required}"
}

main() {
    parse_args "$@"

    if ! is_positive_integer "${MIN_DISK_GB}" || ! is_positive_integer "${MIN_MEM_GB}" || ! is_positive_integer "${HTTP_TIMEOUT_SEC}"; then
        echo "Invalid numeric argument provided" >&2
        exit 1
    fi

    cd "${REPO_ROOT}"

    log "Running preflight checks for ${COMPOSE_FILE}"

    require_bin docker
    require_bin curl
    check_docker_daemon

    # Skip Docker-dependent checks if daemon is unavailable.
    if docker info >/dev/null 2>&1; then
        check_compose_file
        check_port_conflicts
    fi

    check_disk
    check_memory
    check_endpoints

    log "Summary: failures=${FAILURES}, warnings=${WARNINGS}"
    if [ "${FAILURES}" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

main "$@"
