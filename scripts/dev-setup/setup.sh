#!/bin/bash
# =============================================================================
# Deepiri Unified Dev Setup
# Replaces: team_dev_environments/ + team_submodule_commands/
# Usage: bash scripts/dev-setup/setup.sh [--team <team>] [--tier <1|2|3>] [--skip-submodules] [--skip-docker]
# =============================================================================

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TEAM=""; TIER=""; SKIP_SUBMODULES=false; SKIP_DOCKER=false; NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team) TEAM="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    --skip-submodules) SKIP_SUBMODULES=true; shift ;;
    --skip-docker) SKIP_DOCKER=true; shift ;;
    --non-interactive) NON_INTERACTIVE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

BOLD="\033[1m"; CYAN="\033[36m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
header() { echo -e "\n${BOLD}${CYAN}$1${RESET}"; }
ok()     { echo -e "  ${GREEN}✅ $1${RESET}"; }
warn()   { echo -e "  ${YELLOW}⚠️  $1${RESET}"; }
info()   { echo -e "  ℹ️  $1"; }
err()    { echo -e "  ${RED}❌ $1${RESET}"; exit 1; }

echo ""
echo -e "${BOLD}=========================================${RESET}"
echo -e "${BOLD}   Deepiri Unified Dev Setup             ${RESET}"
echo -e "${BOLD}=========================================${RESET}"

# -----------------------------------------------------------------------------
# Step 1: Hardware detection
# -----------------------------------------------------------------------------
header "Step 1/4 — Hardware Detection"

RAM_GB=0; GPU="none"

if [[ -f /proc/meminfo ]]; then
  RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  RAM_GB=$((RAM_KB / 1024 / 1024))
elif command -v sysctl &>/dev/null; then
  RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
fi

if command -v nvidia-smi &>/dev/null 2>&1; then
  GPU="nvidia"
elif [[ "$(uname)" == "Darwin" ]]; then
  GPU="mps"
elif command -v rocm-smi &>/dev/null 2>&1; then
  GPU="amd"
fi

info "RAM: ${RAM_GB}GB  |  GPU: ${GPU}"

# -----------------------------------------------------------------------------
# Step 2: Tier selection
# -----------------------------------------------------------------------------
header "Step 2/4 — Tier Selection"

if [[ -z "$TIER" ]]; then
  if [[ "$GPU" != "none" && $RAM_GB -ge 16 ]]; then SUGGESTED_TIER=1
  elif [[ $RAM_GB -ge 16 ]]; then SUGGESTED_TIER=2
  else SUGGESTED_TIER=3; fi

  echo ""
  echo -e "  Detected hardware suggests ${BOLD}Tier ${SUGGESTED_TIER}${RESET}:"
  echo ""
  echo "  T1 — GPU + 16GB+  : Full stack including Ollama (local LLM)"
  echo "  T2 — No GPU, 16GB+: All services except Ollama"
  echo "  T3 — <16GB        : Core only (postgres, redis, api-gateway, auth)"
  echo ""

  if [[ "$NON_INTERACTIVE" == true ]]; then
    TIER=$SUGGESTED_TIER
  else
    read -rp "  Press Enter for Tier ${SUGGESTED_TIER}, or type 1/2/3 to override: " TIER_INPUT
    TIER="${TIER_INPUT:-$SUGGESTED_TIER}"
  fi
fi

case "$TIER" in
  1) ok "Tier 1 — Full stack with Ollama" ;;
  2) ok "Tier 2 — Full stack, no Ollama" ;;
  3) ok "Tier 3 — Core services only" ;;
  *) err "Invalid tier: $TIER. Must be 1, 2, or 3." ;;
esac

# -----------------------------------------------------------------------------
# Step 3: Team selection
# -----------------------------------------------------------------------------
header "Step 3/4 — Team Selection"

VALID_TEAMS=("ai" "ml" "backend" "frontend" "infrastructure" "cyrex" "platform" "qa")

if [[ -z "$TEAM" ]]; then
  echo ""
  echo "  Teams:"
  echo "    cyrex          — Cyrex AGI only"
  echo "    ai             — Cyrex + MLflow + full backend + synapse + ollama(T1)"
  echo "    ml             — Synapse + sugar-glider only (Helox runs natively)"
  echo "    backend        — All backend microservices + infra"
  echo "    frontend       — Frontend + minimal backend"
  echo "    infrastructure — Same as backend (future: cloud infra)"
  echo "    platform       — Everything (no service filter)"
  echo "    qa             — Full backend with staged startup"
  echo ""
  if [[ "$NON_INTERACTIVE" == true ]]; then err "Non-interactive mode requires --team"; fi
  read -rp "  Which team are you on? " TEAM
fi

TEAM="${TEAM,,}"
VALID=false
for t in "${VALID_TEAMS[@]}"; do [[ "$t" == "$TEAM" ]] && VALID=true; done
[[ "$VALID" == false ]] && err "Unknown team: $TEAM"
ok "Team: ${TEAM}"

# -----------------------------------------------------------------------------
# Service definitions — verified from actual start.sh per team
# These are docker compose SERVICE KEYS (not container_names)
# -----------------------------------------------------------------------------

# Verified: ai-team/start.sh
AI_SERVICES="postgres redis influxdb etcd minio milvus cyrex cyrex-interface mlflow challenge-service api-gateway messaging-service realtime-gateway synapse synapse-sugar-glider"

# Verified: ml-team/start.sh — only these two, helox runs natively
ML_SERVICES="synapse synapse-sugar-glider"

# Verified: backend-team/start.sh and infrastructure-team/start.sh (identical service lists)
BACKEND_INFRA_SERVICES="postgres-auth postgres-core postgres-intelligence redis influxdb api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway language-intelligence-service messaging-service frontend-dev synapse synapse-sugar-glider adminer"

# Verified: frontend-team/start.sh
FRONTEND_SERVICES="frontend-dev api-gateway auth-service communications-hub messaging-service realtime-gateway postgres-auth postgres-core postgres-intelligence"

# Cyrex — minimal AGI stack
CYREX_SERVICES="postgres redis postgres-cyrex cyrex cyrex-interface api-gateway"

# QA infra phase (started first with no --no-deps)
QA_INFRA="postgres-auth postgres-core postgres-intelligence redis influxdb synapse synapse-sugar-glider"
# QA backend phase (started after sleep 3)
QA_BACKEND="api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway adminer"
# QA full list (passed to final up -d for remaining services)
QA_ALL="$QA_INFRA kafka $QA_BACKEND language-intelligence-service messaging-service frontend-dev"

# -----------------------------------------------------------------------------
# Submodule definitions — verified from actual pull_submodules.sh per team
# -----------------------------------------------------------------------------

SHARED_SUBS=(
  "platform-services/shared/deepiri-prismpipe"
  "platform-services/shared/deepiri-shared-utils"
  "platform-services/shared/deepiri-synapse"       # tracks dev branch
  "platform-services/shared/deepiri-sugar-glider"  # tracks dev branch
)

BACKEND_SUBS=(
  "platform-services/backend/deepiri-api-gateway"
  "platform-services/backend/deepiri-auth-service"
  "platform-services/backend/deepiri-external-bridge-service"
  "platform-services/backend/deepiri-language-intelligence-service"
  "deepiri-web-frontend"
)

case "$TEAM" in
  cyrex)
    SUBMODULES=("diri-cyrex" "deepiri-modelkit" "${SHARED_SUBS[@]}")
    ;;
  ai)
    # Verified: ai-team/pull_submodules.sh
    SUBMODULES=("diri-cyrex" "deepiri-ollama-utils" "deepiri-modelkit" "platform-services/backend/deepiri-api-gateway" "${SHARED_SUBS[@]}")
    ;;
  ml)
    # Verified: ml-team/pull_submodules.sh
    SUBMODULES=("diri-helox" "deepiri-modelkit" "deepiri-ollama-utils" "${SHARED_SUBS[@]}")
    ;;
  backend)
    # Verified: backend-team/pull_submodules.sh
    SUBMODULES=("${BACKEND_SUBS[@]}" "${SHARED_SUBS[@]}")
    ;;
  frontend)
    # Verified: frontend-team/pull_submodules.sh
    SUBMODULES=("deepiri-web-frontend" "platform-services/backend/deepiri-api-gateway" "platform-services/backend/deepiri-auth-service" "${SHARED_SUBS[@]}")
    ;;
  infrastructure)
    # Verified: infrastructure-team/pull_submodules.sh (backend repos + shared, no cyrex/helox)
    SUBMODULES=("${BACKEND_SUBS[@]}" "${SHARED_SUBS[@]}")
    ;;
  platform)
    # Verified: platform-engineers/pull_submodules.sh — init all recursively
    SUBMODULES=("ALL")
    ;;
  qa)
    # Verified: qa-team/pull_submodules.sh
    SUBMODULES=(
      "platform-services/shared/deepiri-synapse"
      "platform-services/shared/deepiri-sugar-glider"
      "platform-services/shared/deepiri-shared-utils"
      "platform-services/shared/deepiri-prismpipe"
      "platform-services/backend/deepiri-auth-service"
      "platform-services/backend/deepiri-external-bridge-service"
      "platform-services/backend/deepiri-api-gateway"
      "platform-services/backend/deepiri-language-intelligence-service"
      "deepiri-web-frontend"
      "deepiri-ollama-utils"
    )
    ;;
esac

# -----------------------------------------------------------------------------
# Helper: init submodule with correct branch
# deepiri-synapse and deepiri-sugar-glider track 'dev' per .gitmodules
# -----------------------------------------------------------------------------
init_submodule() {
  local path="$1"
  info "Initializing $path..."

  if [[ -d "$path" && ! -f "$path/.git" && ! -d "$path/.git" ]]; then
    warn "Cleaning invalid directory at $path"
    rm -rf "$path"
  fi

  git submodule update --init --recursive "$path" 2>&1 || true

  if [[ ! -d "$path" ]]; then
    warn "Could not init $path — check SSH key / GitHub access"
    return
  fi

  (
    cd "$path"
    git fetch origin 2>/dev/null || true
    local branch="main"
    case "$path" in
      *deepiri-synapse*|*deepiri-sugar-glider*) branch="dev" ;;
    esac
    if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git show-ref --verify --quiet refs/remotes/origin/master && branch="master"
    fi
    if ! git symbolic-ref -q HEAD &>/dev/null; then
      git checkout -B "$branch" "origin/$branch" 2>/dev/null || true
    fi
    git pull origin "$branch" 2>/dev/null || true
  )

  ok "$path"
}

# -----------------------------------------------------------------------------
# Step 4a: Submodules
# -----------------------------------------------------------------------------
if [[ "$SKIP_SUBMODULES" == false ]]; then
  header "Step 4a/4 — Initializing Submodules (team: ${TEAM})"

  info "Initializing deepiri-suite (base images)..."
  git submodule update --init deepiri-suite 2>&1 && ok "deepiri-suite" || warn "deepiri-suite failed — Docker builds may fall back to GHCR"

  if [[ "${SUBMODULES[0]}" == "ALL" ]]; then
    info "Platform team: initializing all submodules..."
    git submodule update --init --recursive
    ok "All submodules initialized"
  else
    SUBMODULES=($(printf "%s\n" "${SUBMODULES[@]}" | sort -u))
    for sub in "${SUBMODULES[@]}"; do
      init_submodule "$sub"
    done
    ok "All submodules ready"
  fi
else
  warn "Skipping submodules (--skip-submodules)"
fi

# -----------------------------------------------------------------------------
# Step 4b: Docker
# -----------------------------------------------------------------------------
if [[ "$SKIP_DOCKER" == false ]]; then
  header "Step 4b/4 — Starting Docker Services (tier: ${TIER})"

  if ! docker info &>/dev/null; then
    err "Docker is not running. Please start Docker and try again."
  fi

  # Tier 3 override — core only regardless of team
  if [[ "$TIER" == "3" ]]; then
    warn "Tier 3: core services only"
    docker compose -f docker-compose.dev.yml up -d --no-build --no-deps postgres-auth postgres-core redis api-gateway auth-service

  elif [[ "$TEAM" == "platform" ]]; then
    # Verified: platform-engineers/start.sh — no service filter, starts everything
    info "Platform team: starting all services..."
    docker compose -f docker-compose.dev.yml up -d --no-build

  elif [[ "$TEAM" == "qa" ]]; then
    # Verified: qa-team/start.sh — staged startup: infra first, sleep 3, then backend
    info "QA team: staged startup..."
    echo ""
    info "Phase 1: infrastructure services..."
    docker compose -f docker-compose.dev.yml up -d --no-build $QA_INFRA
    info "Waiting 3s for infrastructure to be ready..."
    sleep 3
    info "Phase 2: backend services..."
    docker compose -f docker-compose.dev.yml up -d --no-build --no-deps $QA_BACKEND
    info "Phase 3: remaining services..."
    docker compose -f docker-compose.dev.yml up -d --no-build --no-deps $QA_ALL

  else
    # All other teams: pick services based on team + tier
    case "$TEAM" in
      cyrex)
        SERVICES="$CYREX_SERVICES"
        [[ "$TIER" == "1" ]] && SERVICES="$SERVICES ollama"
        ;;
      ai)
        SERVICES="$AI_SERVICES"
        [[ "$TIER" == "1" ]] && SERVICES="$SERVICES ollama"
        ;;
      ml)
        SERVICES="$ML_SERVICES"
        ;;
      backend|infrastructure)
        SERVICES="$BACKEND_INFRA_SERVICES"
        ;;
      frontend)
        SERVICES="$FRONTEND_SERVICES"
        ;;
    esac

    SERVICES=$(echo "$SERVICES" | tr ' ' '\n' | sort -u | xargs)
    echo ""
    info "Services: $SERVICES"
    echo ""
    docker compose -f docker-compose.dev.yml up -d --no-build --no-deps $SERVICES
  fi

  ok "Docker services started"
else
  warn "Skipping Docker startup (--skip-docker)"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
header "Done"
echo ""
echo -e "  Team: ${BOLD}${TEAM}${RESET}  |  Tier: ${BOLD}${TIER}${RESET}  |  GPU: ${BOLD}${GPU}${RESET}  |  RAM: ${BOLD}${RAM_GB}GB${RESET}"
echo ""
echo "  Endpoints:"
echo "    API Gateway:     http://localhost:5100"
echo "    Cyrex:           http://localhost:8000"
echo "    Cyrex Interface: http://localhost:5175"
echo "    MLflow:          http://localhost:5500"
echo "    Frontend:        http://localhost:5173"
echo "    Synapse:         http://localhost:8002"
[[ "$TIER" == "1" ]] && echo "    Ollama:          http://localhost:11434"
[[ "$GPU" == "mps" ]] && echo "" && echo "  MPS: run Cyrex natively — ollama serve && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "  Commands:"
echo "    Logs:   docker compose -f docker-compose.dev.yml logs -f <service>"
echo "    Status: docker compose -f docker-compose.dev.yml ps"
echo "    Stop:   docker compose -f docker-compose.dev.yml down"
echo ""
