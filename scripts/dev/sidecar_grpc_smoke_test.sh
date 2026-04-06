#!/usr/bin/env bash

# Sidecar gRPC smoke test:
# 1) Health RPC
# 2) Publish RPC
# 3) Subscribe stream RPC
# 4) Ack RPC

set -euo pipefail

GRPC_ADDR="localhost:50051"
STREAM="platform-events"
GROUP="sidecar-grpc-smoke"
CONSUMER=""
ATTEMPTS=12
BATCH_SIZE=25

usage() {
    cat <<'EOF'
Usage: sidecar_grpc_smoke_test.sh [options]

Options:
  --addr <host:port>           Sidecar gRPC address (default: localhost:50051)
  --stream <name>              Redis stream name (default: platform-events)
  --group <name>               Consumer group name (default: sidecar-grpc-smoke)
  --consumer <name>            Consumer name (default: grpc-smoke-<timestamp>)
  --attempts <n>               Subscribe attempts (default: 12)
  --batch-size <n>             Subscribe batch size (default: 25)
  -h, --help                   Show help
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
            --addr)
                GRPC_ADDR="${2:-}"
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
            --batch-size)
                BATCH_SIZE="${2:-}"
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

main() {
    parse_args "$@"
    require_bin go

    local root_dir sidecar_dir consumer_arg
    root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    sidecar_dir="${root_dir}/platform-services/backend/deepiri-realtime-gateway/synapse-sidecar"
    consumer_arg="${CONSUMER}"
    if [ -z "${consumer_arg}" ]; then
        consumer_arg="grpc-smoke-$(date +%s)"
    fi

    (cd "${sidecar_dir}" && go run ./cmd/grpc-smoke \
        --addr "${GRPC_ADDR}" \
        --stream "${STREAM}" \
        --group "${GROUP}" \
        --consumer "${consumer_arg}" \
        --attempts "${ATTEMPTS}" \
        --batch-size "${BATCH_SIZE}")
}

main "$@"
