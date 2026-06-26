#!/usr/bin/env bash
# Install Deepiri Platform via curl:
#   curl -fsSL https://raw.githubusercontent.com/Team-Deepiri/deepiri-platform/main/scripts/install.sh | bash
#
# Clones deepiri-platform and starts the dev stack with Docker Compose.
set -euo pipefail

REPO="Team-Deepiri/deepiri-platform"
REPO_URL="https://github.com/${REPO}.git"
BRANCH="${DEEPIRI_PLATFORM_BRANCH:-main}"
COMPOSE_FILE="${DEEPIRI_PLATFORM_COMPOSE_FILE:-docker-compose.dev.yml}"
KEEP_DIR="${DEEPIRI_PLATFORM_KEEP_DIR:-0}"

usage() {
  cat <<EOF
Usage: install.sh [options]

Bootstrap the Deepiri Platform development stack (Docker Compose).

Options:
  -h, --help       Show this help
  --dry-run        Print actions without cloning or starting services
  --yes            Skip confirmation before docker compose up
  --no-submodules  Skip git submodule init (faster; may break some services)
  --pull-only      Run docker compose pull instead of up -d

Environment:
  DEEPIRI_PLATFORM_SRC              Use an existing checkout
  DEEPIRI_PLATFORM_BRANCH           Git branch (default: main)
  DEEPIRI_PLATFORM_COMPOSE_FILE     Compose file (default: docker-compose.dev.yml)
  DEEPIRI_PLATFORM_KEEP_DIR         Set to 1 to keep the clone directory

Requires: git, docker, docker compose (v2), 8GB+ RAM recommended
Verify:   docker compose -f ${COMPOSE_FILE} ps
EOF
}

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

DRY_RUN=0
ASSUME_YES=0
INIT_SUBMODULES=1
PULL_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --no-submodules) INIT_SUBMODULES=0; shift ;;
    --pull-only) PULL_ONLY=1; shift ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: $1 is required." >&2
    exit 1
  fi
}

require_cmd git
require_cmd docker
if ! docker compose version >/dev/null 2>&1; then
  echo "error: docker compose (v2 plugin) is required." >&2
  exit 1
fi

ROOT=""
CLEANUP=""

resolve_root() {
  if [[ -n "${DEEPIRI_PLATFORM_SRC:-}" && -d "${DEEPIRI_PLATFORM_SRC}" ]]; then
    ROOT="${DEEPIRI_PLATFORM_SRC}"
  elif [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != bash ]] && [[ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docker-compose.yml" ]]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  else
    ROOT="$(mktemp -d)"
    if [[ "$KEEP_DIR" != "1" ]]; then
      CLEANUP="$ROOT"
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "Would clone ${REPO_URL} (branch ${BRANCH}) to ${ROOT}"
      return
    fi
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$ROOT"
  fi
}

resolve_root

if [[ "$DRY_RUN" -eq 1 ]]; then
  [[ "$INIT_SUBMODULES" -eq 1 ]] && log "Would run: git submodule update --init --recursive --depth 1"
  if [[ "$PULL_ONLY" -eq 1 ]]; then
    log "Would run: docker compose -f ${COMPOSE_FILE} pull"
  else
    log "Would run: docker compose -f ${COMPOSE_FILE} up -d"
  fi
  log "Verify: docker compose -f ${COMPOSE_FILE} ps"
  exit 0
fi

trap '[[ -n "$CLEANUP" ]] && rm -rf "$CLEANUP"' EXIT
cd "$ROOT"

if [[ "$INIT_SUBMODULES" -eq 1 && -f .gitmodules ]]; then
  log "Initializing git submodules (shallow)"
  git submodule update --init --recursive --depth 1 || warn "submodule init failed; try --no-submodules or clone with submodules manually"
fi

if [[ "$PULL_ONLY" -eq 1 ]]; then
  log "Pulling images with docker compose"
  docker compose -f "$COMPOSE_FILE" pull
else
  if [[ "$ASSUME_YES" -ne 1 ]]; then
  warn "This will run: docker compose -f ${COMPOSE_FILE} up -d"
  warn "Re-run with --yes to skip this notice."
  fi
  log "Starting platform stack (${COMPOSE_FILE})"
  docker compose -f "$COMPOSE_FILE" up -d
fi

log "Platform services:"
docker compose -f "$COMPOSE_FILE" ps
echo ""
echo "Verify: docker compose -f ${COMPOSE_FILE} ps"
echo "Frontend: http://localhost:5173  API Gateway: http://localhost:5100  Cyrex: http://localhost:8000"
