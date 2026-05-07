#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BENCHMARK_NODE_VERSION="${BENCHMARK_NODE_VERSION:-23.11.0}"
BENCHMARK_NODE_PIN="${BENCHMARK_NODE_PIN:-true}"
BENCHMARK_NODE_PIN_LOWER="$(printf '%s' "${BENCHMARK_NODE_PIN}" | tr '[:upper:]' '[:lower:]')"

cd "${REPO_ROOT}"

resolve_node_bin() {
  if [[ -n "${BENCHMARK_NODE_BIN:-}" ]]; then
    echo "${BENCHMARK_NODE_BIN}"
    return 0
  fi

  if [[ "${BENCHMARK_NODE_PIN_LOWER}" == "true" || "${BENCHMARK_NODE_PIN}" == "1" || "${BENCHMARK_NODE_PIN_LOWER}" == "yes" || "${BENCHMARK_NODE_PIN_LOWER}" == "on" ]]; then
    local candidate
    for candidate in \
      "/opt/homebrew/Cellar/node/${BENCHMARK_NODE_VERSION}/bin/node" \
      "${HOME}/.nvm/versions/node/v${BENCHMARK_NODE_VERSION}/bin/node"; do
      if [[ -x "${candidate}" ]]; then
        echo "${candidate}"
        return 0
      fi
    done
  fi

  command -v node
}

SOCKET_TRANSPORT="polling"
EXPECT_TRANSPORT_ARG_VALUE=0
for arg in "$@"; do
  if [[ "${EXPECT_TRANSPORT_ARG_VALUE}" -eq 1 ]]; then
    SOCKET_TRANSPORT="${arg}"
    EXPECT_TRANSPORT_ARG_VALUE=0
    continue
  fi
  if [[ "${arg}" == "--socket-transport" ]]; then
    EXPECT_TRANSPORT_ARG_VALUE=1
  fi
done

NODE_BIN="$(resolve_node_bin)"
if [[ -z "${NODE_BIN}" ]]; then
  echo "ERROR: unable to resolve Node runtime (set BENCHMARK_NODE_BIN or install node ${BENCHMARK_NODE_VERSION})." >&2
  exit 1
fi

if [[ "${SOCKET_TRANSPORT}" == "websocket" ]]; then
  if ! "${NODE_BIN}" -e 'if (typeof WebSocket !== "function") process.exit(1);' >/dev/null 2>&1; then
    echo "ERROR: websocket benchmark requires a Node runtime with global WebSocket support. node_bin=${NODE_BIN}" >&2
    exit 1
  fi
fi

echo "[benchmark-runner] node_bin=${NODE_BIN} socket_transport=${SOCKET_TRANSPORT} requested_node_version=${BENCHMARK_NODE_VERSION} pin=${BENCHMARK_NODE_PIN}"
"${NODE_BIN}" ./scripts/dev/sugarglider/e2e_gateway_benchmark.js "$@"
