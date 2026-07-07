#!/usr/bin/env bash
# ============================================================================
# Deepiri Platform - Automated Development Environment Setup
# ----------------------------------------------------------------------------
# Consolidates the original setup-deepiri-dev.sh onboarding flow with the
# unified team + hardware-tier dev setup. One script now handles:
#
#   1. Platform detection (macOS / Debian Linux / Debian WSL2)
#   2. Prerequisite install (git, docker, compose, python3, node, npm, ssh)
#   3. GitHub SSH key setup
#   4. Repo clone (or reuse existing clone)
#   5. Team selection (AI / Backend / Frontend / Infrastructure / ML /
#      Platform / QA / Cyrex)
#   6. Hardware detection + tier selection (T1/T2/T3) — decides whether
#      how many services run (T3 = core only). Ollama runs on Linux/WSL,
#      excluded on Mac/MPS, per the original ai-team behavior.
#   7. Team-scoped submodule init (replaces team_submodule_commands/)
#   8. Team + tier-scoped docker compose up (replaces team_dev_environments/)
#   9. Postgres core DB seeding
#
# Usage:
#   bash setup-deepiri-dev.sh [--team <team>] [--tier <1|2|3>]
#                             [--skip-submodules] [--skip-docker]
#                             [--build] [--non-interactive]
# ============================================================================

set -u
set -o pipefail

# ---------- args -----------------------------------------------------------
ARG_TEAM=""; ARG_TIER=""; SKIP_SUBMODULES=false; SKIP_DOCKER=false
DO_BUILD=false; NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team) ARG_TEAM="$2"; shift 2 ;;
        --tier) ARG_TIER="$2"; shift 2 ;;
        --skip-submodules) SKIP_SUBMODULES=true; shift ;;
        --skip-docker) SKIP_DOCKER=true; shift ;;
        --build) DO_BUILD=true; shift ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------- pretty output --------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

step()  { printf "\n${C_BOLD}${C_BLUE}==>${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
info()  { printf "  ${C_CYAN}->${C_RESET} %s\n" "$*"; }
ok()    { printf "  ${C_GREEN}OK${C_RESET}  %s\n" "$*"; }
warn()  { printf "  ${C_YELLOW}!!${C_RESET}  %s\n" "$*"; }
err()   { printf "  ${C_RED}xx${C_RESET}  %s\n" "$*" >&2; }
fatal() { err "$*"; exit 1; }

confirm() {
    local prompt="$1" default="${2:-Y}" answer suffix
    if [[ "$NON_INTERACTIVE" == true ]]; then return 0; fi
    if [[ "$default" =~ ^[Yy]$ ]]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
    read -r -p "  ?? $prompt $suffix " answer || answer=""
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------- platform detection --------------------------------------------
detect_platform() {
    OS_KIND="unknown"; DISTRO_ID=""; PKG_MANAGER=""
    case "$(uname -s)" in
        Darwin) OS_KIND="macos"; PKG_MANAGER="brew" ;;
        Linux)
            if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
                OS_KIND="wsl"; else OS_KIND="linux"; fi
            if [[ -r /etc/os-release ]]; then
                # shellcheck disable=SC1091
                . /etc/os-release; DISTRO_ID="${ID:-}"
            fi
            [[ "$DISTRO_ID" == "debian" ]] && PKG_MANAGER="apt"
            ;;
        *) OS_KIND="unsupported" ;;
    esac
}

require_debian_on_wsl_or_linux() {
    if [[ "$OS_KIND" == "wsl" || "$OS_KIND" == "linux" ]]; then
        if [[ "$DISTRO_ID" != "debian" ]]; then
            err "Detected ${OS_KIND^^} distro: ${DISTRO_ID:-unknown}"
            err "Deepiri requires the Debian distribution on WSL2/Linux."
            err "Install Debian (e.g. \`wsl --install -d Debian\` from PowerShell)"
            err "and re-run from inside that Debian shell."
            exit 1
        fi
        ok "Debian detected (${OS_KIND^^})"
    fi
}

# ---------- hardware detection (from unified setup) -----------------------
detect_hardware() {
    step "Detecting hardware"
    RAM_GB=0; GPU="none"

    if [[ -f /proc/meminfo ]]; then
        local ram_kb; ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        RAM_GB=$((ram_kb / 1024 / 1024))
    elif command -v sysctl >/dev/null 2>&1; then
        local ram_bytes; ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
        RAM_GB=$((ram_bytes / 1024 / 1024 / 1024))
    fi

    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU="nvidia"
    elif [[ "$OS_KIND" == "macos" ]]; then
        GPU="mps"
    elif command -v rocm-smi >/dev/null 2>&1; then
        GPU="amd"
    fi

    info "RAM: ${RAM_GB}GB  |  GPU: ${GPU}"
}

# ---------- tier selection ------------------------------------------------
select_tier() {
    step "Selecting hardware tier"
    if [[ -n "$ARG_TIER" ]]; then
        TIER="$ARG_TIER"
    else
        local suggested
        if [[ "$GPU" != "none" && $RAM_GB -ge 16 ]]; then suggested=1
        elif [[ $RAM_GB -ge 16 ]]; then suggested=2
        else suggested=3; fi

        echo ""
        echo "  T1 - GPU + 16GB+  : Full stack (best for local LLM / Ollama)"
        echo "  T2 - No GPU, 16GB+: Full stack"
        echo "  T3 - <16GB        : Core only (postgres, redis, api-gateway, auth)"
        echo ""
        info "Detected hardware suggests Tier ${suggested}"

        if [[ "$NON_INTERACTIVE" == true ]]; then
            TIER="$suggested"
        else
            local input
            read -r -p "  ?? Press Enter for Tier ${suggested}, or type 1/2/3: " input
            TIER="${input:-$suggested}"
        fi
    fi

    case "$TIER" in
        1) ok "Tier 1 - Full stack (GPU present)" ;;
        2) ok "Tier 2 - Full stack (no GPU)" ;;
        3) ok "Tier 3 - Core services only" ;;
        *) fatal "Invalid tier: $TIER (must be 1, 2, or 3)" ;;
    esac
}

# ---------- team selection ------------------------------------------------
TEAMS_DISPLAY=("AI" "Backend" "Frontend" "Infrastructure" "ML" "Platform" "QA" "Cyrex")
TEAMS_KEY=("ai" "backend" "frontend" "infrastructure" "ml" "platform" "qa" "cyrex")
TEAMS_FOLDER=("ai-team" "backend-team" "frontend-team" "infrastructure-team" "ml-team" "platform-engineers" "qa-team" "")

select_team() {
    if [[ -n "$ARG_TEAM" ]]; then
        TEAM_KEY="${ARG_TEAM,,}"
        local found=false idx
        for idx in "${!TEAMS_KEY[@]}"; do
            if [[ "${TEAMS_KEY[$idx]}" == "$TEAM_KEY" ]]; then
                TEAM_DISPLAY="${TEAMS_DISPLAY[$idx]}"
                TEAM_FOLDER="${TEAMS_FOLDER[$idx]}"
                found=true; break
            fi
        done
        [[ "$found" == true ]] || fatal "Unknown team: $ARG_TEAM"
        ok "Team: $TEAM_DISPLAY"
        return
    fi

    step "Which team are you on?"
    local i
    for i in "${!TEAMS_DISPLAY[@]}"; do
        printf "    %d) %s\n" "$((i + 1))" "${TEAMS_DISPLAY[$i]}"
    done
    local choice
    while :; do
        read -r -p "  ?? Enter a number [1-${#TEAMS_DISPLAY[@]}]: " choice || choice=""
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#TEAMS_DISPLAY[@]} )); then
            TEAM_DISPLAY="${TEAMS_DISPLAY[$((choice - 1))]}"
            TEAM_KEY="${TEAMS_KEY[$((choice - 1))]}"
            TEAM_FOLDER="${TEAMS_FOLDER[$((choice - 1))]}"
            ok "Selected: $TEAM_DISPLAY"
            return
        fi
        warn "Invalid selection. Try again."
    done
}

# ---------- prerequisite installation (from original) ---------------------
need_sudo() {
    if [[ $EUID -eq 0 ]]; then SUDO=""
    elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"
    else SUDO=""; fi
}

apt_install() {
    info "apt-get install: $*"
    $SUDO apt-get update -y >/dev/null
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

ensure_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        info "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
    fi
}

brew_install() { info "brew install: $*"; brew install "$@"; }

install_pkg() {
    local cmd="$1" apt_pkg="$2" brew_pkg="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd already installed ($(command -v "$cmd"))"; return
    fi
    warn "$cmd is missing."
    if ! confirm "Install $cmd now?" "Y"; then
        warn "Skipped $cmd -- install it manually before running services"
        return
    fi
    case "$PKG_MANAGER" in
        apt)  apt_install "$apt_pkg" ;;
        brew) brew_install "$brew_pkg" ;;
        *)    fatal "No supported package manager available to install $cmd" ;;
    esac
    command -v "$cmd" >/dev/null 2>&1 || fatal "Failed to install $cmd"
    ok "$cmd installed"
}

install_docker_wsl() {
    local helper
    if [[ -n "${PLATFORM_REPO_DIR:-}" && -x "$PLATFORM_REPO_DIR/scripts/dev/setup-docker-wsl2.sh" ]]; then
        helper="$PLATFORM_REPO_DIR/scripts/dev/setup-docker-wsl2.sh"
        info "Running repo helper: scripts/dev/setup-docker-wsl2.sh"
        bash "$helper"; return
    fi
    info "Installing Docker Engine + Compose plugin from docker.com apt repo"
    $SUDO apt-get update -y
    $SUDO apt-get install -y ca-certificates curl gnupg lsb-release
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc
    local arch codename
    arch=$(dpkg --print-architecture)
    codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-bookworm}")
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${codename} stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
    $SUDO apt-get update -y
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    $SUDO usermod -aG docker "$USER" || true
    warn "You may need to log out / 'newgrp docker' for the group to apply."
}

ensure_docker() {
    if command -v docker >/dev/null 2>&1; then
        ok "docker already installed ($(docker --version 2>/dev/null | head -1))"
    else
        warn "docker missing -- installing"
        case "$PKG_MANAGER" in
            apt)  install_docker_wsl ;;
            brew) brew_install --cask docker ;;
            *)    fatal "Cannot auto-install Docker on this platform" ;;
        esac
    fi
    if ! docker compose version >/dev/null 2>&1; then
        warn "docker compose plugin not found"
        case "$PKG_MANAGER" in
            apt)  apt_install docker-compose-plugin 2>/dev/null \
                    || warn "docker-compose-plugin not in apt (expected when Docker Desktop provides compose via WSL integration -- enable it in Docker Desktop settings)" ;;
            brew) brew_install docker-compose ;;
        esac
    fi
    if docker info >/dev/null 2>&1; then
        ok "Docker daemon reachable"
    else
        warn "Docker daemon is NOT reachable yet."
        if [[ "$OS_KIND" == "macos" ]]; then
            warn "Open Docker Desktop, wait until 'Engine running', then re-run."
        elif [[ "$OS_KIND" == "wsl" ]]; then
            warn "On WSL2: start Docker Desktop (with WSL integration) or: sudo service docker start"
        else
            warn "Try: sudo systemctl start docker  (or sudo service docker start)"
        fi
        confirm "Docker not running. Continue anyway?" "n" || exit 1
    fi
}

ensure_prereqs() {
    step "Checking prerequisites"
    need_sudo
    [[ "$OS_KIND" == "macos" ]] && ensure_homebrew

    install_pkg git    git    git
    install_pkg curl   curl   curl
    install_pkg python3 python3 python@3.12
    install_pkg pip3   python3-pip python@3.12
    install_pkg node   nodejs node
    install_pkg npm    npm    node
    install_pkg ssh    openssh-client openssh

    ensure_docker

    info "Ensuring pyyaml is available"
    if ! python3 -c "import yaml" >/dev/null 2>&1; then
        if command -v pip3 >/dev/null 2>&1; then
            # Modern Debian/Ubuntu mark the env externally-managed (PEP 668);
            # prefer the apt package, fall back to pip with the override flag.
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                $SUDO apt-get install -y python3-yaml >/dev/null 2>&1 \
                    || pip3 install --user --quiet --break-system-packages pyyaml \
                    || warn "pyyaml install failed (non-fatal)"
            else
                pip3 install --user --quiet pyyaml || warn "pyyaml install failed (non-fatal)"
            fi
        fi
    fi
}

# ---------- SSH key + GitHub (from original) ------------------------------
ensure_ssh_key_for_github() {
    step "Checking GitHub SSH access"
    if [[ "$NON_INTERACTIVE" == true ]]; then
        warn "Non-interactive mode -- skipping SSH key setup"
        return
    fi
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
    local key="$HOME/.ssh/id_ed25519"
    if [[ ! -f "$key" && ! -f "$HOME/.ssh/id_rsa" ]]; then
        warn "No SSH key found in ~/.ssh"
        if confirm "Generate a new ed25519 SSH key now?" "Y"; then
            local email
            read -r -p "  ?? Email for the SSH key: " email
            email="${email:-deepiri-dev@$(hostname)}"
            ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
            ok "Created $key"
        fi
    fi
    if [[ -f "$key.pub" ]]; then
        echo; echo "  ${C_BOLD}Add this public key to GitHub${C_RESET} (https://github.com/settings/ssh/new):"
        echo "  ----------------------------------------------------------------"
        sed 's/^/    /' "$key.pub"
        echo "  ----------------------------------------------------------------"
        command -v xclip >/dev/null 2>&1 && xclip -selection clipboard < "$key.pub" && info "Public key copied (xclip)"
        command -v pbcopy >/dev/null 2>&1 && pbcopy < "$key.pub" && info "Public key copied (pbcopy)"
        if confirm "I've added the key to GitHub. Test the connection?" "Y"; then
            local ssh_out
            ssh_out=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
            if echo "$ssh_out" | grep -qi "successfully authenticated"; then
                ok "GitHub SSH authentication confirmed"
            else
                warn "Could not verify GitHub SSH auth:"; echo "$ssh_out" | sed 's/^/      /'
                confirm "Continue anyway?" "Y" || exit 1
            fi
        fi
    fi
}

# ---------- project dir + clone (from original) ---------------------------
PLATFORM_REPO_URL="git@github.com:Team-Deepiri/deepiri-platform.git"
PLATFORM_REPO_DIR=""

detect_existing_clone() {
    # If the script is being run from inside a deepiri-platform checkout, reuse
    # it instead of cloning a fresh copy. We identify the parent repo by its
    # git remote URL (it is NOT listed in its own .gitmodules, so grepping that
    # file for "deepiri-platform" never matches).
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EXISTING_CLONE=""

    # When the checkout lives on a Windows mount (/mnt/c) and we're in WSL, git
    # flags "dubious ownership" and refuses to read the repo. Add a safe.directory
    # exception so detection (and any later git ops) work.
    if git -C "$script_dir" rev-parse --show-toplevel 2>&1 | grep -q "dubious ownership"; then
        warn "git flagged dubious ownership at $script_dir -- adding safe.directory exception"
        git config --global --add safe.directory "$script_dir" 2>/dev/null || true
    fi

    local toplevel
    toplevel="$(cd "$script_dir" && git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -z "$toplevel" ]] && return

    # Also mark the toplevel safe in case it differs from script_dir
    git config --global --add safe.directory "$toplevel" 2>/dev/null || true

    local remote
    remote="$(git -C "$toplevel" remote get-url origin 2>/dev/null || true)"
    if [[ "$remote" == *deepiri-platform* ]]; then
        EXISTING_CLONE="$toplevel"
    fi
}

choose_project_dir() {
    step "Where should the Deepiri project folder live?"
    local default_dir="$HOME" input
    if [[ "$NON_INTERACTIVE" == true ]]; then
        input=""
    else
        read -r -p "  ?? Parent directory [default: $default_dir]: " input
    fi
    PROJECT_PARENT_DIR="${input:-$default_dir}"
    PROJECT_PARENT_DIR="${PROJECT_PARENT_DIR/#\~/$HOME}"
    mkdir -p "$PROJECT_PARENT_DIR"
    PROJECT_PARENT_DIR="$(cd "$PROJECT_PARENT_DIR" && pwd)"
    PROJECT_ROOT="$PROJECT_PARENT_DIR/Deepiri"
    PLATFORM_REPO_DIR="$PROJECT_ROOT/deepiri-platform"
    ok "Project root: $PROJECT_ROOT"
}

clone_platform_repo() {
    step "Cloning deepiri-platform"
    if [[ -n "$EXISTING_CLONE" ]]; then
        ok "Detected existing clone at: $EXISTING_CLONE"
        if confirm "Use this existing clone?" "Y"; then
            PLATFORM_REPO_DIR="$EXISTING_CLONE"
            PROJECT_ROOT="$(dirname "$PLATFORM_REPO_DIR")"
            ok "Using $PLATFORM_REPO_DIR"; return
        fi
    fi
    mkdir -p "$PROJECT_ROOT"
    if [[ -d "$PLATFORM_REPO_DIR/.git" ]]; then
        ok "Repo already present at $PLATFORM_REPO_DIR -- skipping clone"
    else
        info "git clone $PLATFORM_REPO_URL -> $PLATFORM_REPO_DIR"
        git clone "$PLATFORM_REPO_URL" "$PLATFORM_REPO_DIR"
    fi
}

# ---------- submodules (team-scoped, from unified setup) ------------------
init_submodule() {
    local path="$1"
    info "Initializing $path..."
    if [[ -d "$path" && ! -f "$path/.git" && ! -d "$path/.git" ]]; then
        warn "Cleaning invalid directory at $path"; rm -rf "$path"
    fi
    git submodule update --init --recursive "$path" 2>&1 || true
    if [[ ! -d "$path" ]]; then
        warn "Could not init $path -- check SSH key / GitHub access"; return
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
        if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
            git checkout -B "$branch" "origin/$branch" 2>/dev/null || true
        fi
        git pull origin "$branch" 2>/dev/null || true
    )
    ok "$path"
}

pull_submodules() {
    step "Initializing submodules ($TEAM_DISPLAY)"
    cd "$PLATFORM_REPO_DIR"

    info "Initializing deepiri-suite (base images)..."
    git submodule update --init deepiri-suite 2>&1 && ok "deepiri-suite" \
        || warn "deepiri-suite failed -- Docker builds may fall back to GHCR"

    local SHARED=(
        "platform-services/shared/deepiri-prismpipe"
        "platform-services/shared/deepiri-shared-utils"
        "platform-services/shared/deepiri-synapse"
        "platform-services/shared/deepiri-sugar-glider"
    )
    local BACKEND=(
        "platform-services/backend/deepiri-api-gateway"
        "platform-services/backend/deepiri-auth-service"
        "platform-services/backend/deepiri-external-bridge-service"
        "platform-services/backend/deepiri-language-intelligence-service"
        "deepiri-web-frontend"
    )
    local SUBS=()
    case "$TEAM_KEY" in
        cyrex)          SUBS=("diri-cyrex" "deepiri-modelkit" "${SHARED[@]}") ;;
        ai)             SUBS=("diri-cyrex" "deepiri-ollama-utils" "deepiri-modelkit" "platform-services/backend/deepiri-api-gateway" "${SHARED[@]}") ;;
        ml)             SUBS=("diri-helox" "deepiri-modelkit" "deepiri-ollama-utils" "${SHARED[@]}") ;;
        backend)        SUBS=("${BACKEND[@]}" "${SHARED[@]}") ;;
        frontend)       SUBS=("deepiri-web-frontend" "platform-services/backend/deepiri-api-gateway" "platform-services/backend/deepiri-auth-service" "${SHARED[@]}") ;;
        infrastructure) SUBS=("${BACKEND[@]}" "${SHARED[@]}") ;;
        platform)       SUBS=("ALL") ;;
        qa)             SUBS=(
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
                        ) ;;
    esac

    if [[ "${SUBS[0]}" == "ALL" ]]; then
        info "Platform team: initializing all submodules..."
        git submodule update --init --recursive
        ok "All submodules initialized"
    else
        local uniq; uniq=$(printf "%s\n" "${SUBS[@]}" | sort -u)
        while IFS= read -r sub; do
            [[ -n "$sub" ]] && init_submodule "$sub"
        done <<< "$uniq"
        ok "Submodules ready for $TEAM_DISPLAY"
    fi
}

# ---------- docker (team + tier-scoped, from unified setup) ---------------
start_services() {
    step "Starting Docker services ($TEAM_DISPLAY, Tier $TIER)"
    cd "$PLATFORM_REPO_DIR"

    if ! docker info >/dev/null 2>&1; then
        warn "Docker is not running -- skipping service startup"
        return
    fi

    local build_flag="--no-build"
    [[ "$DO_BUILD" == true ]] && build_flag=""

    # Service lists verified against team_dev_environments/<team>/start.sh
    local AI="postgres redis influxdb etcd minio milvus cyrex cyrex-interface mlflow challenge-service api-gateway messaging-service realtime-gateway synapse sugar-glider"
    local ML="synapse sugar-glider"
    local BACKEND_INFRA="postgres-auth postgres-core postgres-intelligence redis influxdb api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway language-intelligence-service messaging-service frontend-dev synapse sugar-glider adminer"
    local FRONTEND="frontend-dev api-gateway auth-service communications-hub messaging-service realtime-gateway postgres-auth postgres-core postgres-intelligence"
    local CYREX="postgres redis postgres-cyrex cyrex cyrex-interface api-gateway"
    local QA_INFRA="postgres-auth postgres-core postgres-intelligence redis influxdb synapse sugar-glider"
    local QA_BACKEND="api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway adminer"
    local QA_ALL="$QA_INFRA kafka $QA_BACKEND language-intelligence-service messaging-service frontend-dev"

    # Tier 3 override for all teams
    if [[ "$TIER" == "3" ]]; then
        warn "Tier 3: core services only"
        docker compose -f docker-compose.dev.yml up -d $build_flag --no-deps \
            postgres-auth postgres-core redis api-gateway auth-service
        ok "Services started"
        return
    fi

    case "$TEAM_KEY" in
        platform)
            info "Platform team: starting all services..."
            docker compose -f docker-compose.dev.yml up -d $build_flag
            ;;
        qa)
            info "QA team: staged startup..."
            docker compose -f docker-compose.dev.yml up -d $build_flag $QA_INFRA
            info "Waiting 3s for infrastructure..."; sleep 3
            docker compose -f docker-compose.dev.yml up -d $build_flag --no-deps $QA_BACKEND
            docker compose -f docker-compose.dev.yml up -d $build_flag --no-deps $QA_ALL
            ;;
        *)
            local services
            case "$TEAM_KEY" in
                cyrex)          services="$CYREX" ;;
                ai)             services="$AI" ;;
                ml)             services="$ML" ;;
                backend|infrastructure) services="$BACKEND_INFRA" ;;
                frontend)       services="$FRONTEND" ;;
            esac

            # Ollama handling for the AI team (matches original ai-team start.sh):
            # Ollama runs in Docker on Linux / WSL (cuda or other backend).
            # On Mac (MPS) cyrex and ollama run natively, NOT in Docker, so exclude both.
            if [[ "$TEAM_KEY" == "ai" ]]; then
                if [[ "$GPU" == "mps" ]]; then
                    warn "MPS (Mac) detected — excluding cyrex and ollama from Docker (run natively instead)"
                    services=$(echo "$services" | tr ' ' '\n' | grep -vE '^(cyrex|ollama)$' | xargs)
                else
                    services="$services ollama"
                fi
            fi

            services=$(echo "$services" | tr ' ' '\n' | sort -u | xargs)
            info "Services: $services"
            docker compose -f docker-compose.dev.yml up -d $build_flag --no-deps $services
            ;;
    esac

    ok "Services started"
    info "Running containers:"
    docker ps --format "    {{.Names}}\t{{.Status}}" | head -40
}

# ---------- DB seeding (from original) ------------------------------------
seed_databases() {
    step "Seeding databases"
    local seed_sql="$PLATFORM_REPO_DIR/scripts/database/postgres-seed.sql"
    [[ -f "$seed_sql" ]] || { warn "$seed_sql not found -- nothing to seed"; return; }

    local container="deepiri-postgres-core-dev"
    local user="${POSTGRES_CORE_USER:-deepiri}"
    local db="${POSTGRES_CORE_DB:-deepiri}"

    if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
        warn "$container not running -- skipping seed"
        warn "Later: docker exec -i $container psql -U $user -d $db < scripts/database/postgres-seed.sql"
        return
    fi

    info "Waiting for postgres-core..."
    local i
    for i in $(seq 1 60); do
        docker exec "$container" pg_isready -U "$user" -d "$db" >/dev/null 2>&1 && { ok "postgres-core ready"; break; }
        sleep 2
        (( i == 60 )) && { warn "postgres-core not ready in 120s -- skipping seed"; return; }
    done

    info "Applying postgres-seed.sql"
    if docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U "$user" -d "$db" < "$seed_sql"; then
        ok "Seed data applied"
    else
        warn "Seed reported errors -- re-run later:"
        warn "  docker exec -i $container psql -U $user -d $db < scripts/database/postgres-seed.sql"
    fi
}

# ---------- summary -------------------------------------------------------
print_summary() {
    step "All done!"
    cat <<EOF
  ${C_BOLD}Team:${C_RESET}          $TEAM_DISPLAY
  ${C_BOLD}Tier:${C_RESET}          $TIER
  ${C_BOLD}Hardware:${C_RESET}      ${RAM_GB}GB RAM, GPU: ${GPU}
  ${C_BOLD}Platform repo:${C_RESET} $PLATFORM_REPO_DIR

  Endpoints:
    API Gateway:     http://localhost:5100
    Cyrex:           http://localhost:8000
    Cyrex Interface: http://localhost:5175
    MLflow:          http://localhost:5500
    Frontend:        http://localhost:5173
    Synapse:         http://localhost:8002
EOF
    if [[ "$TEAM_KEY" == "ai" && "$GPU" != "mps" && "$TIER" != "3" ]]; then
        echo "    Ollama:          http://localhost:11434"
    fi
    cat <<EOF

  Useful commands (from $PLATFORM_REPO_DIR):
    docker compose -f docker-compose.dev.yml logs -f <service>
    docker compose -f docker-compose.dev.yml ps
    docker compose -f docker-compose.dev.yml down

  ${C_YELLOW}Reminder:${C_RESET} drop your /secrets folder into
    $PLATFORM_REPO_DIR/ops/k8s/secrets
  before services that need them will start cleanly.

  Next up: check Plaky for tasks. See #kanban on Discord.
EOF
}

# ---------- main ----------------------------------------------------------
main() {
    step "Deepiri Platform :: dev environment setup"
    detect_platform
    info "OS: $OS_KIND  distro: ${DISTRO_ID:-n/a}  pkg: ${PKG_MANAGER:-n/a}"
    require_debian_on_wsl_or_linux
    [[ "$OS_KIND" != "unsupported" ]] || fatal "Unsupported OS: $(uname -s)"

    detect_existing_clone
    select_team
    detect_hardware
    select_tier
    ensure_prereqs
    ensure_ssh_key_for_github
    choose_project_dir
    clone_platform_repo

    [[ "$SKIP_SUBMODULES" == true ]] && warn "Skipping submodules (--skip-submodules)" || pull_submodules
    [[ "$SKIP_DOCKER" == true ]] && warn "Skipping Docker (--skip-docker)" || start_services

    seed_databases
    print_summary
}

main "$@"
