#!/usr/bin/env bash

# Sugar Glider smoke test:
# 1) Verify Sugar Glider readiness
# 2) Publish a unique event
# 3) Read until that event is observed
# 4) Ack the event

set -euo pipefail

SUGAR_GLIDER_URL="http://localhost:8081"
STREAM="platform-events"
GROUP="sugar-glider-smoke"
CONSUMER="smoke-$(date +%s)"
ATTEMPTS=15
BLOCK_MS=1000
COUNT=100

log() {
    printf '%s\n' "$*"
}

usage() {
    cat <<'USAGE'
Usage: sugar_glider_smoke_test.sh [options]

Options:
  --url <sugar-glider-url>    Sugar Glider base URL (default: http://localhost:8081)
  --stream <name>             Redis stream name (default: platform-events)
  --group <name>              Consumer group name (default: sugar-glider-smoke)
  --consumer <name>           Consumer name (default: smoke-<timestamp>)
  --attempts <n>              Read attempts before timeout (default: 15)
  --block-ms <ms>             Block time per read call (default: 1000)
  --count <n>                 Max events per read call (default: 100)
  -h, --help                  Show help
USAGE
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
            --url)
                SUGAR_GLIDER_URL="${2:-}"
                shift 2
                ;;
            --stream)
                STREAM="${2:-}"
                shift 2
                ;;
            --group)
                GROUP="${2:-}"
                shift 2
                ;;
            --consumer)
                CONSUMER="${2:-}"
                shift 2
                ;;
            --attempts)
                ATTEMPTS="${2:-}"
                shift 2
                ;;
            --block-ms)
                BLOCK_MS="${2:-}"
                shift 2
                ;;
            --count)
                COUNT="${2:-}"
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

main() {
    parse_args "$@"

    if ! is_positive_integer "${ATTEMPTS}" || ! is_positive_integer "${BLOCK_MS}" || ! is_positive_integer "${COUNT}"; then
        echo "attempts, block-ms, and count must be positive integers" >&2
        exit 1
    fi

    require_bin curl
    require_bin jq

    local ready_payload smoke_id publish_body publish_resp entry_id
    local payload_json read_body read_resp events_len match_id ack_body ack_resp acked

    log "Checking Sugar Glider readiness: ${SUGAR_GLIDER_URL}/readyz"
    ready_payload="$(curl -fsS --max-time 5 "${SUGAR_GLIDER_URL}/readyz")" || {
        echo "Sugar Glider readiness endpoint is unavailable." >&2
        exit 1
    }
    if ! echo "${ready_payload}" | jq -e '.ready == true' >/dev/null 2>&1; then
        echo "Sugar Glider is not ready: ${ready_payload}" >&2
        exit 1
    fi

    smoke_id="smoke-$(date +%s)-${RANDOM}"
    payload_json="$(jq -cn --arg smoke_id "${smoke_id}" --arg source "sugar_glider_smoke_test" --arg ts "$(date -u +%FT%TZ)" '{smoke_id: $smoke_id, source: $source, timestamp: $ts}')"
    publish_body="$(jq -cn \
        --arg stream "${STREAM}" \
        --arg event_type "smoke.test" \
        --arg sender "sugar-glider-smoke-test" \
        --argjson payload "${payload_json}" \
        '{stream: $stream, event_type: $event_type, sender: $sender, priority: "normal", payload: $payload}')"

    log "Publishing smoke event to ${STREAM} (smoke_id=${smoke_id})"
    publish_resp="$(curl -fsS --max-time 8 -X POST "${SUGAR_GLIDER_URL}/v1/publish" -H 'Content-Type: application/json' -d "${publish_body}")"
    entry_id="$(echo "${publish_resp}" | jq -r '.entry_id // empty')"
    if [ -z "${entry_id}" ]; then
        echo "Publish did not return entry_id: ${publish_resp}" >&2
        exit 1
    fi
    log "Published entry_id=${entry_id}"

    read_body="$(jq -cn \
        --arg stream "${STREAM}" \
        --arg group "${GROUP}" \
        --arg consumer "${CONSUMER}" \
        --argjson count "${COUNT}" \
        --argjson block_ms "${BLOCK_MS}" \
        '{stream: $stream, consumer_group: $group, consumer_name: $consumer, count: $count, block_ms: $block_ms}')"

    for attempt in $(seq 1 "${ATTEMPTS}"); do
        read_resp="$(curl -fsS --max-time 10 -X POST "${SUGAR_GLIDER_URL}/v1/read" -H 'Content-Type: application/json' -d "${read_body}")"
        events_len="$(echo "${read_resp}" | jq -r '(.events // []) | length')"
        log "Read attempt ${attempt}/${ATTEMPTS}: events=${events_len}"

        match_id="$(echo "${read_resp}" | jq -r --arg entry_id "${entry_id}" --arg smoke_id "${smoke_id}" '
            (.events // [])
            | map(select((.entry_id == $entry_id) or ((.fields.payload // "" | tostring | contains($smoke_id)))))
            | .[0].entry_id // empty
        ')"

        if [ -n "${match_id}" ]; then
            log "Matched smoke event entry_id=${match_id}, acking..."
            ack_body="$(jq -cn --arg stream "${STREAM}" --arg group "${GROUP}" --arg id "${match_id}" '{stream: $stream, consumer_group: $group, entry_ids: [$id]}')"
            ack_resp="$(curl -fsS --max-time 8 -X POST "${SUGAR_GLIDER_URL}/v1/ack" -H 'Content-Type: application/json' -d "${ack_body}")"
            acked="$(echo "${ack_resp}" | jq -r '.acked // 0')"
            if [ "${acked}" -ge 1 ]; then
                log "PASS: Sugar Glider smoke test succeeded (publish/read/ack)"
                exit 0
            fi
            echo "Ack did not acknowledge the entry: ${ack_resp}" >&2
            exit 1
        fi
    done

    echo "Timed out waiting for smoke event entry_id=${entry_id}" >&2
    exit 1
}

main "$@"
