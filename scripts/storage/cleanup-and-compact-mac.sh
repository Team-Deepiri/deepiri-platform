#!/usr/bin/env bash
# Deepiri Docker cleanup (macOS / Linux) — only names/repos containing "deepiri"
# (plus optional Docker-wide build cache, same caveat as the Windows script).
# There is no WSL/VHDX path on Unix; use the .ps1 script on Windows for that.
#
# Usage:
#   ./cleanup-and-compact-mac.sh                 # full Deepiri cleanup (no build cache)
#   ./cleanup-and-compact-mac.sh -i              # interactive menu
#   ./cleanup-and-compact-mac.sh --targets images,volumes
#
set -euo pipefail

DEEPIRI="deepiri"

# shellcheck disable=SC2034
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux" ;;
  *)      OS="unknown" ;;
esac

echo_color() {
  local color=$1
  shift
  case $color in
    red)    printf '\033[0;31m%s\033[0m\n' "$*" ;;
    green)  printf '\033[0;32m%s\033[0m\n' "$*" ;;
    yellow) printf '\033[1;33m%s\033[0m\n' "$*" ;;
    cyan)   printf '\033[0;36m%s\033[0m\n' "$*" ;;
    *)      printf '%s\n' "$*" ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INTERACTIVE=false
DO_IMAGES=false
DO_VOLUMES=false
DO_CONTAINERS=false
DO_NETWORKS=false
DO_BUILD_CACHE=false

usage() {
  sed -n '1,15p' "$0" | tail -n +2
  echo ""
  echo "Options:"
  echo "  -i, --interactive          Prompt for operations"
  echo "  -t, --targets LIST        Comma-separated: images,volumes,containers,networks,buildcache,all"
  echo "  -h, --help                This help"
}

parse_targets() {
  local list=$1
  IFS=',' read -ra PARTS <<< "$list"
  for p in "${PARTS[@]}"; do
    case "$(echo "$p" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
      images)      DO_IMAGES=true ;;
      volumes)     DO_VOLUMES=true ;;
      containers)  DO_CONTAINERS=true ;;
      networks)    DO_NETWORKS=true ;;
      buildcache)   DO_BUILD_CACHE=true ;;
      all)
        DO_IMAGES=true; DO_VOLUMES=true; DO_CONTAINERS=true; DO_NETWORKS=true
        ;;
      *) echo_color red "Unknown target: $p"; exit 1 ;;
    esac
  done
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--interactive) INTERACTIVE=true; shift ;;
    -t|--targets)
      [[ -n "${2:-}" ]] || { echo_color red "Missing value for --targets"; exit 1; }
      parse_targets "$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo_color red "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if $INTERACTIVE; then
  echo_color cyan "=========================================="
  echo_color cyan "Select what to clean (Deepiri-scoped)"
  echo_color cyan "=========================================="
  echo ""
  echo "  [1] Deepiri Docker images (repository contains '$DEEPIRI')"
  echo "  [2] Deepiri Docker volumes"
  echo "  [3] Deepiri containers"
  echo "  [4] Deepiri Docker networks"
  echo "  [5] Docker build cache (Docker-wide unused cache — not project-filtered)"
  echo "  [6] All Deepiri Docker (1–4); build cache only if you also choose 5"
  echo ""
  read -r -p "Enter numbers separated by commas (default: 6): " choice
  choice=${choice:-6}
  IFS=',' read -ra nums <<< "$choice"
  for n in "${nums[@]}"; do
    n="$(echo "$n" | tr -d '[:space:]')"
    case $n in
      1) DO_IMAGES=true ;;
      2) DO_VOLUMES=true ;;
      3) DO_CONTAINERS=true ;;
      4) DO_NETWORKS=true ;;
      5) DO_BUILD_CACHE=true ;;
      6) DO_IMAGES=true; DO_VOLUMES=true; DO_CONTAINERS=true; DO_NETWORKS=true ;;
      *) echo_color yellow "Ignoring unknown choice: $n" ;;
    esac
  done
  echo ""
elif ! $DO_IMAGES && ! $DO_VOLUMES && ! $DO_CONTAINERS && ! $DO_NETWORKS && ! $DO_BUILD_CACHE; then
  # Default: same as --targets all (no build cache)
  DO_IMAGES=true; DO_VOLUMES=true; DO_CONTAINERS=true; DO_NETWORKS=true
fi

ANY_DOCKER=false
if $DO_IMAGES || $DO_VOLUMES || $DO_CONTAINERS || $DO_NETWORKS || $DO_BUILD_CACHE; then
  ANY_DOCKER=true
fi

echo_color cyan "=========================================="
echo_color cyan "Deepiri Docker cleanup ($OS)"
echo_color cyan "=========================================="
echo ""

if [[ "$OS" == "darwin" ]]; then
  echo_color yellow "[INFO] macOS: reclaiming Docker Desktop VM disk may still require Docker Desktop → Troubleshoot → Clean / Purge data, or: docker run --rm --privileged docker/desktop-reclaim-space"
  echo ""
fi

echo_color yellow "[INFO] Checking Docker..."
if ! command -v docker &>/dev/null; then
  echo_color red "[ERROR] Docker is not installed or not in PATH."
  exit 1
fi
echo_color green "[OK] Docker CLI available"
echo ""

if $ANY_DOCKER; then
  echo_color yellow "Note: 'docker system df' is Docker-wide (informational). Removals are Deepiri-named resources only (except optional build cache)."
  docker system df || true
  echo ""
fi

# --- Stop / remove Deepiri containers ---
if $DO_CONTAINERS || $DO_IMAGES; then
  echo_color yellow "[INFO] Stopping Deepiri containers..."
  while IFS= read -r cname; do
    [[ -z "$cname" ]] && continue
    echo_color yellow "  Stopping: $cname"
    docker stop "$cname" 2>/dev/null || true
  done < <(docker ps -a --filter "name=$DEEPIRI" --format '{{.Names}}' 2>/dev/null || true)

  if [[ -f "$REPO_ROOT/docker-compose.yml" ]]; then
    echo_color yellow "[INFO] docker compose down (repo root)..."
    (cd "$REPO_ROOT" && docker compose -f docker-compose.yml down 2>/dev/null || true)
    (cd "$REPO_ROOT" && docker compose -f docker-compose.dev.yml down 2>/dev/null || true)
    (cd "$REPO_ROOT" && docker compose -f docker-compose.microservices.yml down 2>/dev/null || true)
    (cd "$REPO_ROOT" && docker compose -f docker-compose.enhanced.yml down 2>/dev/null || true)
  fi

  if $DO_CONTAINERS; then
    echo_color yellow "[INFO] Removing Deepiri containers..."
    while IFS= read -r cid; do
      [[ -z "$cid" ]] && continue
      docker rm -f "$cid" 2>/dev/null || true
    done < <(docker ps -a -q --filter "name=$DEEPIRI" 2>/dev/null || true)
  fi
  echo_color green "[OK] Container step complete"
  echo ""
fi

# --- Images (repository contains deepiri) ---
if $DO_IMAGES; then
  echo_color yellow "[INFO] Removing Deepiri images..."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    repo="${line%%:*}"
    if echo "$repo" | grep -qi "$DEEPIRI"; then
      echo_color yellow "  Removing: $line"
      docker rmi -f "$line" 2>/dev/null || true
    fi
  done < <(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null || true)
  echo_color green "[OK] Image step complete"
  echo ""
fi

# --- Volumes ---
if $DO_VOLUMES; then
  echo_color yellow "[INFO] Removing Deepiri volumes..."
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    if echo "$vol" | grep -qi "$DEEPIRI"; then
      echo_color yellow "  Removing volume: $vol"
      docker volume rm -f "$vol" 2>/dev/null || true
    fi
  done < <(docker volume ls -q 2>/dev/null || true)
  echo_color green "[OK] Volume step complete"
  echo ""
fi

# --- Networks (skip bridge/host/none) ---
if $DO_NETWORKS; then
  echo_color yellow "[INFO] Removing Deepiri networks..."
  while IFS= read -r net; do
    [[ -z "$net" ]] && continue
    [[ "$net" == "bridge" || "$net" == "host" || "$net" == "none" ]] && continue
    if echo "$net" | grep -qi "$DEEPIRI"; then
      echo_color yellow "  Removing network: $net"
      docker network rm "$net" 2>/dev/null || true
    fi
  done < <(docker network ls --format '{{.Name}}' 2>/dev/null || true)
  echo_color green "[OK] Network step complete"
  echo ""
fi

if $DO_BUILD_CACHE; then
  echo_color yellow "[INFO] Pruning build cache (Docker-wide)..."
  docker builder prune -af 2>/dev/null || true
  echo_color green "[OK] Build cache pruned"
  echo ""
fi

if $ANY_DOCKER; then
  echo_color yellow "[INFO] Docker disk usage after cleanup:"
  docker system df || true
  echo ""
fi

echo_color cyan "=========================================="
echo_color cyan "Deepiri Docker cleanup complete ($OS)"
echo_color cyan "=========================================="
echo ""
echo_color green "[OK] Selected Deepiri-scoped steps finished."
echo_color cyan "Restart Docker Desktop manually if needed."
echo ""
