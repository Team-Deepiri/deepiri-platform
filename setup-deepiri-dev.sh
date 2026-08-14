#!/usr/bin/env bash
# ============================================================================
# Deepiri Platform - Dev environment (onboard + day-to-day team ops)
# ----------------------------------------------------------------------------
# Single entrypoint. Team services/submodules live in teams/<team>.yml
# (pure bash YAML parser in this script). Catalogs: teams/all-services.yml,
# teams/all-submodules.yml. Audit: teams/TEAM_INVENTORY_AUDIT.md
#
# Onboard (no args):
#   1. Pick team (QA tiers 1–3 mirror frontend / backend / ai)
#   2. Prereqs (git, docker, compose, python3, node, npm, ssh); Debian on WSL/Linux
#   3. Clone (or reuse) deepiri-platform
#   4. pull → build → start from teams/<team>.yml, then seed postgres-core
#
# Day-to-day (same script):
#   ./setup-deepiri-dev.sh pull   ai-team
#   ./setup-deepiri-dev.sh build  ai-team
#   ./setup-deepiri-dev.sh start  ai-team
#   ./setup-deepiri-dev.sh stop   ai-team
#   ./setup-deepiri-dev.sh stop-rm ai-team
#   ./setup-deepiri-dev.sh restart ai-team
#   ./setup-deepiri-dev.sh show   ai-team
#   ./setup-deepiri-dev.sh list-teams
#
# Speech (livekit + speech): listed in teams/ai-team.yml; see
# docs/architecture/DEEPIRI_SPEECH_INTEGRATION.md
# ============================================================================

set -u
set -o pipefail

# ---------- pretty output --------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

step()    { printf "\n${C_BOLD}${C_BLUE}==>${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
info()    { printf "  ${C_CYAN}->${C_RESET} %s\n" "$*"; }
ok()      { printf "  ${C_GREEN}OK${C_RESET}  %s\n" "$*"; }
warn()    { printf "  ${C_YELLOW}!!${C_RESET}  %s\n" "$*"; }
err()     { printf "  ${C_RED}xx${C_RESET}  %s\n" "$*" >&2; }
fatal()   { err "$*"; exit 1; }

confirm() {
    # confirm "Question" [default Y|n]
    local prompt="$1" default="${2:-Y}" answer suffix
    if [[ "$default" =~ ^[Yy]$ ]]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
    read -r -p "  ?? $prompt $suffix " answer || answer=""
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------- platform detection --------------------------------------------
detect_platform() {
    OS_KIND="unknown"     # linux | macos | wsl | unsupported
    DISTRO_ID=""
    PKG_MANAGER=""

    case "$(uname -s)" in
        Darwin)
            OS_KIND="macos"
            PKG_MANAGER="brew"
            ;;
        Linux)
            if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
                OS_KIND="wsl"
            else
                OS_KIND="linux"
            fi
            if [[ -r /etc/os-release ]]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                DISTRO_ID="${ID:-}"
            fi
            if [[ "$DISTRO_ID" == "debian" ]]; then
                PKG_MANAGER="apt"
            fi
            ;;
        *)
            OS_KIND="unsupported"
            ;;
    esac
}

require_debian_on_wsl_or_linux() {
    if [[ "$OS_KIND" == "wsl" || "$OS_KIND" == "linux" ]]; then
        if [[ "$DISTRO_ID" != "debian" ]]; then
            err "Detected ${OS_KIND^^} distro: ${DISTRO_ID:-unknown}"
            err "Deepiri requires the Debian distribution on WSL2/Linux."
            err "Install Debian (e.g. \`wsl --install -d Debian\` from PowerShell)"
            err "and re-run this script from inside that Debian shell."
            exit 1
        fi
        ok "Debian detected (${OS_KIND^^})"
    fi
}

# ---------- team selection ------------------------------------------------
TEAMS_DISPLAY=("AI" "Backend" "Frontend" "Infrastructure" "ML" "Platform" "QA")
TEAMS_FOLDER=("ai-team" "backend-team" "frontend-team" "infrastructure-team" "ml-team" "platform-engineers" "qa-team")

# QA tiers reuse the matching eng team's submodule + compose env.
# Tier 1 = frontend stack, Tier 2 = backend stack, Tier 3 = AI stack.
QA_TIER=""
QA_TIER_LABELS=("Frontend stack" "Backend stack" "AI stack")
QA_TIER_FOLDERS=("frontend-team" "backend-team" "ai-team")

select_qa_tier() {
    step "Which QA tier are you?"
    info "QA tiers match machine capacity to the same services eng teams run."
    echo
    printf "    1) Tier 1 — Frontend stack\n"
    printf "       Same services as Frontend engineers (lighter machines).\n"
    printf "    2) Tier 2 — Backend stack\n"
    printf "       Same services as Backend engineers (includes frontend).\n"
    printf "    3) Tier 3 — AI stack\n"
    printf "       Same services as AI engineers; can also run Tier 1 or 2.\n"
    echo
    local choice
    while :; do
        read -r -p "  ?? Enter a number [1-3]: " choice || choice=""
        if [[ "$choice" =~ ^[123]$ ]]; then
            QA_TIER="$choice"
            TEAM_FOLDER="${QA_TIER_FOLDERS[$((choice - 1))]}"
            TEAM_DISPLAY="QA Tier ${QA_TIER} (${QA_TIER_LABELS[$((choice - 1))]})"
            ok "Selected: $TEAM_DISPLAY → teams/$TEAM_FOLDER.yml"
            info "Submodules + build/start use $TEAM_FOLDER (same as that eng team)."
            return
        fi
        warn "Invalid selection. Enter 1, 2, or 3."
    done
}

select_team() {
    step "Which team are you on?"
    local i
    for i in "${!TEAMS_DISPLAY[@]}"; do
        printf "    %d) %s\n" "$((i + 1))" "${TEAMS_DISPLAY[$i]}"
    done
    local choice
    while :; do
        read -r -p "  ?? Enter a number [1-${#TEAMS_DISPLAY[@]}]: " choice || choice=""
        if [[ "$choice" =~ ^[0-9]+$ ]] \
           && (( choice >= 1 && choice <= ${#TEAMS_DISPLAY[@]} )); then
            TEAM_DISPLAY="${TEAMS_DISPLAY[$((choice - 1))]}"
            TEAM_FOLDER="${TEAMS_FOLDER[$((choice - 1))]}"
            if [[ "$TEAM_DISPLAY" == "QA" ]]; then
                select_qa_tier
            else
                ok "Selected: $TEAM_DISPLAY ($TEAM_FOLDER)"
            fi
            # Speech: AI stack (and QA Tier 3) must start livekit + speech when in compose.
            case "$TEAM_FOLDER" in
                ai-team)
                    info "Speech: ai-team SERVICES lists livekit + speech (compose must define them)"
                    ;;
                platform-engineers|infrastructure-team)
                    info "Speech: included once livekit + speech exist in docker-compose.dev.yml"
                    ;;
            esac
            return
        fi
        warn "Invalid selection. Try again."
    done
}

# ---------- prerequisite installation -------------------------------------
need_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        SUDO=""
    fi
}

apt_install() {
    info "apt-get install: $*"
    $SUDO apt-get update -y >/dev/null
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

ensure_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        info "Homebrew not found. Installing..."
        /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for this session (works for both Apple Silicon and Intel)
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

brew_install() {
    info "brew install: $*"
    brew install "$@"
}

install_pkg() {
    # install_pkg <command-to-check> <apt-package> <brew-formula>
    local cmd="$1" apt_pkg="$2" brew_pkg="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd already installed ($(command -v "$cmd"))"
        return
    fi
    warn "$cmd missing -- installing"
    case "$PKG_MANAGER" in
        apt)  apt_install "$apt_pkg" ;;
        brew) brew_install "$brew_pkg" ;;
        *)    fatal "No supported package manager available to install $cmd" ;;
    esac
    command -v "$cmd" >/dev/null 2>&1 || fatal "Failed to install $cmd"
    ok "$cmd installed"
}

install_docker_wsl() {
    # Use the repo's existing helper if we can find it, otherwise inline a
    # minimal install of docker-ce + compose plugin from Docker's apt repo.
    local helper
    if [[ -n "${PLATFORM_REPO_DIR:-}" \
          && -x "$PLATFORM_REPO_DIR/scripts/dev/setup-docker-wsl2.sh" ]]; then
        helper="$PLATFORM_REPO_DIR/scripts/dev/setup-docker-wsl2.sh"
        info "Running repo helper: scripts/dev/setup-docker-wsl2.sh"
        bash "$helper"
        return
    fi
    info "Installing Docker Engine + Compose plugin from docker.com apt repo"
    $SUDO apt-get update -y
    $SUDO apt-get install -y ca-certificates curl gnupg lsb-release
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc
    local arch codename
    arch=$(dpkg --print-architecture)
    codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-bookworm}")
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${codename} stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
    $SUDO apt-get update -y
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
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
        warn "docker compose plugin missing -- installing"
        case "$PKG_MANAGER" in
            apt)  apt_install docker-compose-plugin ;;
            brew) brew_install docker-compose ;;
        esac
    fi
    if docker info >/dev/null 2>&1; then
        ok "Docker daemon reachable"
    else
        warn "Docker daemon is NOT reachable yet."
        if [[ "$OS_KIND" == "macos" ]]; then
            warn "Open Docker Desktop, wait until it says 'Engine running', then re-run."
        elif [[ "$OS_KIND" == "wsl" ]]; then
            warn "On WSL2: start Docker Desktop on Windows (with WSL integration enabled),"
            warn "or start the Linux daemon: sudo service docker start"
        else
            warn "Try: sudo systemctl start docker  (or sudo service docker start)"
        fi
        confirm "Docker not running. Continue anyway?" "n" || exit 1
    fi
}

ensure_prereqs() {
    step "Checking prerequisites"
    need_sudo
    if [[ "$OS_KIND" == "macos" ]]; then
        ensure_homebrew
    fi

    install_pkg git    git    git
    install_pkg curl   curl   curl
    install_pkg python3 python3 python@3.12
    install_pkg pip3   python3-pip python@3.12
    install_pkg node   nodejs node
    install_pkg npm    npm    node
    install_pkg ssh    openssh-client openssh

    ensure_docker

    info "Team envs are YAML-driven: ./setup-deepiri-dev.sh pull|build|start <team> (see teams/*.yml)"
}

# ---------- SSH key + GitHub --------------------------------------------
ensure_ssh_key_for_github() {
    step "Checking GitHub SSH access"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    local key="$HOME/.ssh/id_ed25519"
    if [[ ! -f "$key" && ! -f "$HOME/.ssh/id_rsa" ]]; then
        warn "No SSH key found in ~/.ssh"
        if confirm "Generate a new ed25519 SSH key now?" "Y"; then
            local email
            read -r -p "  ?? Email for the SSH key (used as comment): " email
            email="${email:-deepiri-dev@$(hostname)}"
            ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
            ok "Created $key"
        fi
    fi

    if [[ -f "$key.pub" ]]; then
        echo
        echo "  ${C_BOLD}Add this public key to GitHub${C_RESET}"
        echo "  (https://github.com/settings/ssh/new):"
        echo "  ----------------------------------------------------------------"
        cat "$key.pub" | sed 's/^/    /'
        echo "  ----------------------------------------------------------------"
        if command -v xclip >/dev/null 2>&1; then
            xclip -selection clipboard < "$key.pub" \
                && info "Public key copied to clipboard (xclip)"
        elif command -v pbcopy >/dev/null 2>&1; then
            pbcopy < "$key.pub" && info "Public key copied to clipboard (pbcopy)"
        fi
        if confirm "I've added the key to GitHub. Test the connection?" "Y"; then
            local ssh_out
            ssh_out=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
                          -T git@github.com 2>&1 || true)
            if echo "$ssh_out" | grep -qi "successfully authenticated"; then
                ok "GitHub SSH authentication confirmed"
            else
                warn "Could not verify GitHub SSH auth. Output:"
                echo "$ssh_out" | sed 's/^/      /'
                confirm "Continue anyway?" "Y" || exit 1
            fi
        fi
    fi
}

# ---------- project directory + clone -------------------------------------
PLATFORM_REPO_URL="git@github.com:Team-Deepiri/deepiri-platform.git"
PLATFORM_REPO_DIR=""

choose_project_dir() {
    step "Where should the Deepiri project folder live?"
    local default_dir="$HOME"
    local input
    read -r -p "  ?? Parent directory [default: $default_dir]: " input
    PROJECT_PARENT_DIR="${input:-$default_dir}"
    # Expand ~ if user typed it
    PROJECT_PARENT_DIR="${PROJECT_PARENT_DIR/#\~/$HOME}"
    mkdir -p "$PROJECT_PARENT_DIR"
    PROJECT_PARENT_DIR="$(cd "$PROJECT_PARENT_DIR" && pwd)"
    PROJECT_ROOT="$PROJECT_PARENT_DIR/Deepiri"
    PLATFORM_REPO_DIR="$PROJECT_ROOT/deepiri-platform"
    ok "Project root: $PROJECT_ROOT"
}

# Detect whether the script is already running from inside a deepiri-platform
# clone -- in that case, skip cloning and reuse it.
detect_existing_clone() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # When the checkout lives on a Windows mount (/mnt/c) and we're in WSL, git
    # flags "dubious ownership" and refuses to read the repo. Add a safe.directory
    # exception so detection (and any later git ops) work.
    if git -C "$script_dir" rev-parse --show-toplevel 2>&1 | grep -q "dubious ownership"; then
        warn "git flagged dubious ownership at $script_dir -- adding safe.directory exception"
        git config --global --add safe.directory "$script_dir" 2>/dev/null || true
    fi

    local toplevel
    toplevel="$(cd "$script_dir" && git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$toplevel" ]]; then
        EXISTING_CLONE=""
        return
    fi
    # Also mark the toplevel safe in case it differs from script_dir
    git config --global --add safe.directory "$toplevel" 2>/dev/null || true

    if [[ -f "$toplevel/.gitmodules" ]] \
       && grep -q "Team-Deepiri/" \
                  "$toplevel/.gitmodules" 2>/dev/null; then
        EXISTING_CLONE="$toplevel"
    else
        EXISTING_CLONE=""
    fi
}

clone_platform_repo() {
    step "Cloning deepiri-platform"
    if [[ -n "$EXISTING_CLONE" ]]; then
        ok "Detected existing clone at: $EXISTING_CLONE"
        if confirm "Use this existing clone instead of cloning into $PLATFORM_REPO_DIR?" "Y"; then
            PLATFORM_REPO_DIR="$EXISTING_CLONE"
            PROJECT_ROOT="$(dirname "$PLATFORM_REPO_DIR")"
            ok "Using $PLATFORM_REPO_DIR"
            return
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

# ---------- team ops (pure bash, teams/*.yml) ------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAM_COMPOSE_FILE="docker-compose.dev.yml"

declare -A TEAM_DOCKERFILE_HINTS=(
    [api-gateway]="platform-services/backend/deepiri-api-gateway/Dockerfile"
    [auth-service]="platform-services/backend/deepiri-auth-service/Dockerfile"
    [external-bridge-service]="platform-services/backend/deepiri-external-bridge-service/Dockerfile"
    [language-intelligence-service]="platform-services/backend/deepiri-language-intelligence-service/Dockerfile"
    [synapse]="platform-services/shared/deepiri-synapse/Dockerfile"
    [sugar-glider]="platform-services/shared/deepiri-sugar-glider/Dockerfile"
    [frontend-dev]="deepiri-web-frontend/Dockerfile"
    [cyrex]="diri-cyrex/Dockerfile"
    [speech]="platform-services/backend/deepiri-speech/Dockerfile"
    [deepiri-prismpipe]="platform-services/shared/deepiri-prismpipe/Dockerfile"
)

team_repo_root() { echo "${PLATFORM_REPO_DIR:-$SCRIPT_DIR}"; }
team_teams_dir() { echo "$(team_repo_root)/teams"; }

team_run() {
    local check=1 rc
    if [[ "${1:-}" == "--no-check" ]]; then check=0; shift; fi
    printf '+ %s\n' "$*"
    ( cd "$(team_repo_root)" && "$@" )
    rc=$?
    if (( check )) && (( rc != 0 )); then exit "$rc"; fi
    return "$rc"
}

team_yaml_strip() {
    local v="$1"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    v="${v%%#*}"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    if [[ "$v" =~ ^\"(.*)\"$ ]]; then v="${BASH_REMATCH[1]}"; fi
    if [[ "$v" =~ ^\'(.*)\'$ ]]; then v="${BASH_REMATCH[1]}"; fi
    echo "$v"
}

team_yaml_bool() {
    case "$(team_yaml_strip "${1:-false}")" in
        true|True|yes|Yes|1) echo "true" ;;
        *) echo "false" ;;
    esac
}

team_yaml_reset() {
    TEAM_YAML_ID=""
    TEAM_YAML_DISPLAY=""
    TEAM_YAML_SERVICES_MODE="list"
    TEAM_YAML_SERVICES=()
    TEAM_YAML_SUBMODULES_MODE="list"
    TEAM_YAML_SUBMODULES=()
    TEAM_YAML_DISABLED_SERVICES=()
    TEAM_YAML_URLS=()
    TEAM_BUILD_BUILDKIT="false"
    TEAM_BUILD_SEQUENTIAL="false"
    TEAM_BUILD_ENSURE_SUITE="true"
    TEAM_BUILD_ENSURE_SHARED="true"
    TEAM_BUILD_DOCKER_PULL=()
    TEAM_BUILD_OPTIONAL=()
    TEAM_BUILD_PULL_ONLY=()
    TEAM_BUILD_HAS_PULL_ONLY="false"
    TEAM_START_NO_DEPS="true"
    TEAM_START_EXCLUDE_MPS=()
    TEAM_START_REQUIRE_DF=()
    TEAM_START_OPTIONAL=()
    TEAM_START_PHASE_WAIT=0
    TEAM_START_PHASE_COUNT=0
    TEAM_PULL_RECURSIVE="true"
    TEAM_PULL_CHECKOUT_MAIN="true"
    TEAM_PULL_SETUP_HOOKS="true"
    TEAM_PULL_ALL_RECURSIVE="false"
    TEAM_PULL_OPTIONAL=()
}

team_yaml_append_list() {
    local key="$1" val="$2"
    val="$(team_yaml_strip "$val")"
    [[ -z "$val" || "$val" == \#* ]] && return 0
    if [[ "$val" =~ ^path:[[:space:]]*(.+)$ ]]; then
        val="$(team_yaml_strip "${BASH_REMATCH[1]}")"
    fi
    case "$key" in
        services) TEAM_YAML_SERVICES+=("$val") ;;
        submodules) TEAM_YAML_SUBMODULES+=("$val") ;;
        disabled_services) TEAM_YAML_DISABLED_SERVICES+=("$val") ;;
        urls) TEAM_YAML_URLS+=("$val") ;;
        build_docker_pull) TEAM_BUILD_DOCKER_PULL+=("$val") ;;
        build_optional) TEAM_BUILD_OPTIONAL+=("$val") ;;
        build_pull_only) TEAM_BUILD_PULL_ONLY+=("$val"); TEAM_BUILD_HAS_PULL_ONLY="true" ;;
        start_exclude_mps) TEAM_START_EXCLUDE_MPS+=("$val") ;;
        start_require_df) TEAM_START_REQUIRE_DF+=("$val") ;;
        start_optional) TEAM_START_OPTIONAL+=("$val") ;;
        pull_optional) TEAM_PULL_OPTIONAL+=("$val") ;;
    esac
}

team_yaml_parse_phase_line() {
    local item="$1"
    [[ "$item" =~ ^\[(.*)\]$ ]] || return 1
    local inner="${BASH_REMATCH[1]}" csv part
    local -a parts=()
    IFS=',' read -ra parts <<< "$inner"
    local -a phase_items=()
    for part in "${parts[@]}"; do
        part="$(team_yaml_strip "$part")"
        [[ -n "$part" ]] && phase_items+=("$part")
    done
    local idx="$TEAM_START_PHASE_COUNT"
    eval "TEAM_START_PHASE_${idx}=()"
    local -n _p="TEAM_START_PHASE_${idx}"
    _p=("${phase_items[@]}")
    TEAM_START_PHASE_COUNT=$((idx + 1))
}

team_yaml_load() {
    local file="$1"
    local section="" list_key="" in_phases=0
    team_yaml_reset
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ ! "$line" =~ ^[[:space:]]+- ]] \
           && [[ "$line" =~ ^([a-z_]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}" rest="${BASH_REMATCH[2]}"
            rest="$(team_yaml_strip "$rest")"
            list_key=""
            in_phases=0
            case "$key" in
                build|start|pull) section="$key"; continue ;;
                id) TEAM_YAML_ID="$rest"; section="top"; continue ;;
                display) TEAM_YAML_DISPLAY="$rest"; section="top"; continue ;;
                services)
                    if [[ "$rest" == "all" ]]; then TEAM_YAML_SERVICES_MODE="all"
                    else list_key="services"; fi
                    section="top"; continue ;;
                submodules)
                    if [[ "$rest" == "all" ]]; then TEAM_YAML_SUBMODULES_MODE="all"
                    else list_key="submodules"; fi
                    section="top"; continue ;;
                disabled_services) list_key="disabled_services"; section="top"; continue ;;
                urls) list_key="urls"; section="top"; continue ;;
                *) section="top"; continue ;;
            esac
        fi

        if [[ -n "$section" && "$section" != "top" ]] \
           && [[ ! "$line" =~ ^[[:space:]]+- ]] \
           && [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]*(.*)$ ]]; then
            local nkey="${BASH_REMATCH[1]}" nval="${BASH_REMATCH[2]}"
            nval="$(team_yaml_strip "$nval")"
            case "$section:$nkey" in
                build:buildkit) TEAM_BUILD_BUILDKIT="$(team_yaml_bool "$nval")" ;;
                build:sequential) TEAM_BUILD_SEQUENTIAL="$(team_yaml_bool "$nval")" ;;
                build:ensure_suite_images) TEAM_BUILD_ENSURE_SUITE="$(team_yaml_bool "$nval")" ;;
                build:ensure_shared_utils) TEAM_BUILD_ENSURE_SHARED="$(team_yaml_bool "$nval")" ;;
                build:docker_pull) list_key="build_docker_pull"; in_phases=0 ;;
                build:optional) list_key="build_optional"; in_phases=0 ;;
                build:pull_only) list_key="build_pull_only"; in_phases=0 ;;
                start:no_deps) TEAM_START_NO_DEPS="$(team_yaml_bool "$nval")" ;;
                start:exclude_on_mps) list_key="start_exclude_mps"; in_phases=0 ;;
                start:require_dockerfile) list_key="start_require_df"; in_phases=0 ;;
                start:optional) list_key="start_optional"; in_phases=0 ;;
                start:phase_wait_seconds) TEAM_START_PHASE_WAIT="${nval:-0}" ;;
                start:phases) list_key=""; in_phases=1 ;;
                pull:recursive) TEAM_PULL_RECURSIVE="$(team_yaml_bool "$nval")" ;;
                pull:checkout_main) TEAM_PULL_CHECKOUT_MAIN="$(team_yaml_bool "$nval")" ;;
                pull:setup_hooks) TEAM_PULL_SETUP_HOOKS="$(team_yaml_bool "$nval")" ;;
                pull:all_recursive) TEAM_PULL_ALL_RECURSIVE="$(team_yaml_bool "$nval")" ;;
                pull:optional) list_key="pull_optional"; in_phases=0 ;;
            esac
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*)$ ]]; then
            local item="${BASH_REMATCH[1]}"
            item="${item%%#*}"
            item="$(team_yaml_strip "$item")"
            [[ -z "$item" ]] && continue
            if (( in_phases )); then
                team_yaml_parse_phase_line "$item" || true
                continue
            fi
            [[ -n "$list_key" ]] && team_yaml_append_list "$list_key" "$item"
        fi
    done < "$file"
}

team_catalog_list() {
    local catalog="$1" list_key="$2"
    local in_list=0 item
    local -a out=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        if [[ "$line" =~ ^${list_key}:[[:space:]]*$ ]]; then
            in_list=1; continue
        fi
        if (( in_list )) && [[ "$line" =~ ^[a-zA-Z0-9_-]+: ]]; then break; fi
        if (( in_list )) && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+path:[[:space:]]*(.+)$ ]]; then
            item="${BASH_REMATCH[1]%%#*}"
            out+=("$(team_yaml_strip "$item")")
        elif (( in_list )) && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+([^[:space:]]+)([[:space:]]|$) ]]; then
            item="$(team_yaml_strip "${BASH_REMATCH[1]}")"
            [[ "$item" != path:* ]] && out+=("$item")
        fi
    done < "$catalog"
    printf '%s\n' "${out[@]}"
}

team_resolve_alias() {
    case "$1" in
        ai) echo "ai-team" ;;
        backend) echo "backend-team" ;;
        frontend) echo "frontend-team" ;;
        infrastructure|infra) echo "infrastructure-team" ;;
        ml) echo "ml-team" ;;
        platform|platform-engineers|all) echo "platform-engineers" ;;
        qa) echo "qa-team" ;;
        qa-tier-1|qa:1|qa1) echo "frontend-team" ;;
        qa-tier-2|qa:2|qa2) echo "backend-team" ;;
        qa-tier-3|qa:3|qa3) echo "ai-team" ;;
        *) echo "$1" ;;
    esac
}

team_list_ids() {
    local f base skip="all-services all-submodules"
    for f in "$(team_teams_dir)"/*.yml; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f" .yml)"
        [[ " $skip " == *" $base "* ]] && continue
        echo "$base"
    done | sort
}

team_known_names() {
    team_list_ids
    printf '%s\n' ai backend frontend infrastructure infra ml platform platform-engineers qa all \
        qa-tier-1 qa-tier-2 qa-tier-3 qa:1 qa:2 qa:3 qa1 qa2 qa3
}

team_resolve_yml() {
    local team resolved path
    team="$1"
    resolved="$(team_resolve_alias "$team")"
    path="$(team_teams_dir)/${resolved}.yml"
    if [[ ! -f "$path" ]]; then
        err "Unknown team '$team'. Known: $(team_known_names | sort -u | paste -sd, -)"
        return 1
    fi
    echo "$path"
}

team_resolve_services() {
    local -a services=() disabled=() s d
    if [[ "$TEAM_YAML_SERVICES_MODE" == "all" ]]; then
        mapfile -t services < <(team_catalog_list "$(team_teams_dir)/all-services.yml" "services")
    else
        services=("${TEAM_YAML_SERVICES[@]}")
    fi
    disabled=("${TEAM_YAML_DISABLED_SERVICES[@]}")
    for s in "${services[@]}"; do
        [[ "$s" == \#* ]] && continue
        local skip=0
        for d in "${disabled[@]}"; do
            [[ "$s" == "$d" ]] && skip=1 && break
        done
        (( skip )) || echo "$s"
    done
}

team_resolve_submodules() {
    if [[ "$TEAM_YAML_SUBMODULES_MODE" == "all" ]]; then
        team_catalog_list "$(team_teams_dir)/all-submodules.yml" "submodules"
    else
        printf '%s\n' "${TEAM_YAML_SUBMODULES[@]}"
    fi
}

team_pull_only_set() {
    local -a pull_only=()
    if [[ "$TEAM_BUILD_HAS_PULL_ONLY" == "true" ]]; then
        pull_only=("${TEAM_BUILD_PULL_ONLY[@]}")
    else
        mapfile -t pull_only < <(team_catalog_list "$(team_teams_dir)/all-services.yml" "pull_only")
    fi
    printf '%s\n' "${pull_only[@]}"
}

team_in_list() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}

team_shared_utils_path() { echo "$(team_repo_root)/platform-services/shared/deepiri-shared-utils"; }

team_dockerfiles_need_shared_utils() {
    local backend="$(team_repo_root)/platform-services/backend" df
    [[ -d "$backend" ]] || return 0
    for df in "$backend"/*/Dockerfile; do
        [[ -f "$df" ]] || continue
        if grep -qE 'shared-utils/dist|shared-utils/node_modules' "$df" 2>/dev/null; then
            echo "$df"
        fi
    done
}

team_ensure_shared_utils() {
    local force="${1:-0}" needing pkg dist_index node_modules su
    su="$(team_shared_utils_path)"
    mapfile -t needing < <(team_dockerfiles_need_shared_utils)
    if (( force == 0 )) && ((${#needing[@]} == 0)); then
        echo "shared-utils: Dockerfiles build it in-image — no host prep needed"
        return 0
    fi
    if ((${#needing[@]} > 0)); then
        echo "shared-utils fallback: host dist required by:"
        local p root; root="$(team_repo_root)"
        for p in "${needing[@]}"; do echo "   - ${p#"$root"/}"; done
    fi
    pkg="$su/package.json"
    [[ -f "$pkg" ]] || fatal "shared-utils package.json missing — pull platform-services/shared/deepiri-shared-utils first"
    dist_index="$su/dist/index.js"
    node_modules="$su/node_modules"
    if [[ -f "$dist_index" && -d "$node_modules" ]]; then
        echo "shared-utils host fallback ready (platform-services/shared/deepiri-shared-utils/dist/index.js)"
        return 0
    fi
    echo "Preparing deepiri-shared-utils on host (npm install + build)…"
    command -v npm >/dev/null 2>&1 || fatal "npm is required for shared-utils host fallback"
    ( cd "$su" && npm install --legacy-peer-deps --workspaces=false ) \
        || fatal "Failed: npm install in platform-services/shared/deepiri-shared-utils"
    ( cd "$su" && npm run build ) \
        || fatal "Failed: npm run build in platform-services/shared/deepiri-shared-utils"
    [[ -f "$dist_index" ]] || fatal "shared-utils build did not produce $dist_index"
    echo "shared-utils host dist + node_modules ready"
}

team_ensure_suite_images() {
    local suite_dir="${DEEPIRI_SUITE_CONTEXT:-$(team_repo_root)/deepiri-suite}"
    local base tag img all_ok=1
    echo "Ensuring deepiri-suite base images..."
    for entry in "node:18-alpine|18-alpine" "node:18-slim|18-slim" "node:20-alpine|20-alpine"; do
        base="${entry%%|*}"
        tag="${entry##*|}"
        img="ghcr.io/team-deepiri/deepiri-suite:${tag}"
        if docker image inspect "$img" >/dev/null 2>&1; then
            echo "   ok $img (cached)"
            continue
        fi
        echo "   Pulling $img from GHCR..."
        if docker pull "$img" >/dev/null 2>&1; then
            echo "   ok $img (pulled)"
            continue
        fi
        echo "   GHCR pull failed -- building locally (BASE_IMAGE=$base)"
        if [[ ! -f "$suite_dir/Dockerfile" ]]; then
            echo "   deepiri-suite not found at $suite_dir"
            echo "      Run: ./setup-deepiri-dev.sh pull <team>"
            all_ok=0
            continue
        fi
        if team_run --no-check docker build --build-arg "BASE_IMAGE=$base" -t "$img" "$suite_dir"; then
            echo "   ok $img (built locally)"
        else
            echo "   Failed to build $img locally"
            all_ok=0
        fi
    done
    (( all_ok )) || exit 1
}

team_detect_backend() {
    if command -v nvidia-smi >/dev/null 2>&1; then echo "cuda"
    elif [[ "$(uname -s)" == "Darwin" ]]; then echo "mps"
    else echo "other"; fi
}

team_check_submodule() {
    local rel="$1" path
    path="$(team_repo_root)/$rel"
    [[ -d "$path" ]] || return 1
    [[ -e "$path/.git" ]] || return 1
    ( cd "$path" && git rev-parse --git-dir >/dev/null 2>&1 )
}

team_cleanup_invalid_submodule() {
    local rel="$1" path
    path="$(team_repo_root)/$rel"
    if [[ -d "$path" ]] && ! team_check_submodule "$rel"; then
        echo "    Directory exists but is not a valid submodule. Cleaning $rel..."
        rm -rf "$path"
    fi
}

team_ensure_submodule_on_main() {
    local rel="$1" path branch has_main has_master detached cur
    path="$(team_repo_root)/$rel"
    [[ -d "$path" ]] || return 0
    ( cd "$path" && git fetch origin >/dev/null 2>&1 ) || true
    branch="main"
    has_main=1 has_master=1
    ( cd "$path" && git show-ref --verify --quiet refs/remotes/origin/main ) || has_main=0
    ( cd "$path" && git show-ref --verify --quiet refs/remotes/origin/master ) || has_master=0
    if (( !has_main && has_master )); then branch="master"
    elif (( !has_main && !has_master )); then
        echo "    No main/master for $rel, skipping checkout"; return 0
    fi
    if ( cd "$path" && ! git symbolic-ref -q HEAD >/dev/null 2>&1 ); then
        ( cd "$path" && git checkout -B "$branch" "origin/$branch" >/dev/null 2>&1 ) || true
    else
        cur="$(cd "$path" && git symbolic-ref --short HEAD 2>/dev/null || true)"
        if [[ "$cur" != "$branch" ]]; then
            ( cd "$path" && git checkout "$branch" >/dev/null 2>&1 ) || true
        fi
    fi
    ( cd "$path" && git branch "--set-upstream-to=origin/$branch" "$branch" >/dev/null 2>&1 ) || true
    ( cd "$path" && git pull origin "$branch" >/dev/null 2>&1 ) || true
}

team_cmd_pull() {
    local team_id="$1" display="${TEAM_YAML_DISPLAY:-$team_id}" sm root hooks team_hooks
    root="$(team_repo_root)"
    echo "$display — pulling submodules"
    [[ -d "$root/.git" ]] || fatal "Not a git repo: $root"
    team_run --no-check git pull origin main
    local -a subs=() optional=()
    mapfile -t subs < <(team_resolve_submodules)
    mapfile -t optional < <(printf '%s\n' "${TEAM_PULL_OPTIONAL[@]}")
    if [[ "$TEAM_YAML_SUBMODULES_MODE" == "all" || "$TEAM_PULL_ALL_RECURSIVE" == "true" ]]; then
        team_run git submodule update --init --recursive
        for sm in "${subs[@]}"; do echo "  ready: $sm"; done
    else
        for sm in "${subs[@]}"; do
            echo "  Initializing $sm..."
            team_cleanup_invalid_submodule "$sm"
            mkdir -p "$(dirname "$root/$sm")"
            local -a init_cmd=(git submodule update --init)
            [[ "$TEAM_PULL_RECURSIVE" == "true" ]] && init_cmd+=(--recursive)
            init_cmd+=("$sm")
            local rc=0
            team_run --no-check "${init_cmd[@]}" || rc=$?
            if team_check_submodule "$sm"; then
                if (( rc != 0 )); then
                    echo "    ok $sm (already present; submodule update skipped — local changes or pin unavailable)"
                else
                    if [[ "$TEAM_PULL_CHECKOUT_MAIN" == "true" ]]; then
                        team_run --no-check git submodule update --remote "$sm"
                        team_ensure_submodule_on_main "$sm"
                    fi
                    echo "    ok $sm"
                fi
                continue
            fi
            if team_in_list "$sm" "${optional[@]}"; then
                echo "    Failed to init $sm (optional)"
            else
                echo "    Failed to init $sm"
                exit 1
            fi
        done
    fi
    if [[ "$TEAM_PULL_SETUP_HOOKS" == "true" ]]; then
        hooks="$root/setup-hooks.sh"
        [[ -f "$hooks" ]] && team_run --no-check bash "$hooks"
        team_sync_hooks_to_submodules
    fi
    echo "Submodules ready for $display"
}

# Sync .git-hooks into each of this team's submodules (driven by the same
# teams/<team>.yml submodule list as the pull above). Formerly the per-team
# team_submodule_commands/<team>/setup-hooks.sh scripts; consolidated here so
# the team YAML is the single source of truth for the submodule set.
team_sync_hooks_to_submodules() {
    local subs root path
    root="$(team_repo_root)"
    [[ -d "$root/.git-hooks" ]] || return 0
    mapfile -t subs < <(team_resolve_submodules)
    for rel in "${subs[@]}"; do
        path="$root/$rel"
        [[ -d "$path/.git" ]] || [[ -f "$path/.git" ]] || continue
        ( cd "$path" && git rev-parse --git-dir >/dev/null 2>&1 ) || continue
        mkdir -p "$path/.git-hooks"
        cp "$root/.git-hooks/"* "$path/.git-hooks/" 2>/dev/null || true
        chmod +x "$path/.git-hooks/"* 2>/dev/null || true
        ( cd "$path" && git config core.hooksPath .git-hooks ) 2>/dev/null || true
        echo "  hooks synced: $rel"
    done
}

team_image_exists_for_service() {
    local service="$1" base aliases img
    declare -A aliases=([frontend-dev]=frontend [deepiri-prismpipe]=prismpipe)
    base="${aliases[$service]:-$service}"
    for img in "deepiri-dev-${base}:latest" "deepiri-dev-${base}" \
               "deepiri-dev-${service}:latest" "deepiri-dev-${service}"; do
        docker image inspect "$img" >/dev/null 2>&1 && return 0
    done
    return 1
}

team_build_one_service() {
    local s="$1"
    local -n _failed="$2"
    local -n _optional_build="$3"
    local nc=()
    [[ "${TEAM_BUILD_NO_CACHE:-0}" == "1" ]] && nc=(--no-cache)
    echo "-- Building $s --"
    if team_run --no-check docker compose -f "$TEAM_COMPOSE_FILE" build "${nc[@]}" "$s"; then return 0; fi
    if team_in_list "$s" "${_optional_build[@]}"; then
        echo "OPTIONAL FAIL $s (continuing)"
        return 0
    fi
    _failed+=("$s")
    echo "FAILED $s"
    return 1
}

team_cmd_build() {
    local team_id="$1" display="${TEAM_YAML_DISPLAY:-$team_id}"
    local -a services=() pull_only=() buildable=() failed=() optional_build=() img svc
    mapfile -t services < <(team_resolve_services)
    mapfile -t pull_only < <(team_pull_only_set)
    mapfile -t optional_build < <(printf '%s\n' "${TEAM_BUILD_OPTIONAL[@]}")
    export DOCKER_BUILDKIT="$([[ "$TEAM_BUILD_BUILDKIT" == "true" ]] && echo 1 || echo 0)"
    export COMPOSE_DOCKER_CLI_BUILD="$DOCKER_BUILDKIT"
    [[ "$TEAM_BUILD_ENSURE_SUITE" == "true" ]] && team_ensure_suite_images
    [[ "$TEAM_BUILD_ENSURE_SHARED" == "true" ]] && team_ensure_shared_utils
    echo "Building $display services..."
    ((${#services[@]} == 0)) && { echo "No services listed"; return 0; }
    for img in "${TEAM_BUILD_DOCKER_PULL[@]}"; do
        echo "Pulling $img..."
        team_run --no-check docker pull "$img"
    done
    for svc in "${services[@]}"; do
        team_in_list "$svc" "${pull_only[@]}" || buildable+=("$svc")
    done
    if ((${#buildable[@]} == 0)) && [[ "$TEAM_YAML_SERVICES_MODE" != "all" ]]; then
        echo "Nothing to build (all services are pull-only)"
        return 0
    fi
    if [[ "$TEAM_YAML_SERVICES_MODE" == "all" ]]; then
        mapfile -t buildable < <(
            docker compose -f "$TEAM_COMPOSE_FILE" config --services \
            | while read -r s; do team_in_list "$s" "${pull_only[@]}" || echo "$s"; done
        )
    fi
    if [[ "$TEAM_BUILD_SEQUENTIAL" == "true" ]]; then
        for svc in "${buildable[@]}"; do team_build_one_service "$svc" failed optional_build || true; done
    elif ((${#buildable[@]} > 0)); then
        local nc=()
        [[ "${TEAM_BUILD_NO_CACHE:-0}" == "1" ]] && nc=(--no-cache)
        if ! team_run --no-check docker compose -f "$TEAM_COMPOSE_FILE" build "${nc[@]}" "${buildable[@]}"; then
            for svc in "${buildable[@]}"; do team_build_one_service "$svc" failed optional_build || true; done
        fi
    fi
    if ((${#failed[@]} > 0)); then
        echo "Failed services: ${failed[*]}"
        exit 1
    fi
    echo "$display services built successfully"
}

team_filter_start_services() {
    local -a services=("$@") out=() filtered=() final=() pull_only=() optional=()
    local backend svc hint root
    root="$(team_repo_root)"
    mapfile -t pull_only < <(team_pull_only_set)
    mapfile -t optional < <(printf '%s\n' "${TEAM_START_OPTIONAL[@]}")
    backend="$(team_detect_backend)"
    echo "Detected backend: $backend"
    out=("${services[@]}")
    if [[ "$backend" == "mps" && ${#TEAM_START_EXCLUDE_MPS[@]} -gt 0 ]]; then
        echo "MPS — excluding: $(IFS=,; echo "${TEAM_START_EXCLUDE_MPS[*]}")"
        for svc in "${out[@]}"; do
            team_in_list "$svc" "${TEAM_START_EXCLUDE_MPS[@]}" || filtered+=("$svc")
        done
        out=("${filtered[@]}")
        filtered=()
    fi
    for svc in "${out[@]}"; do
        if team_in_list "$svc" "${TEAM_START_REQUIRE_DF[@]}"; then
            hint="${TEAM_DOCKERFILE_HINTS[$svc]:-}"
            if [[ -n "$hint" && ! -f "$root/$hint" ]]; then
                echo "Skipping $svc (Dockerfile missing: $hint)"
                continue
            fi
        fi
        filtered+=("$svc")
    done
    for svc in "${filtered[@]}"; do
        if team_in_list "$svc" "${pull_only[@]}"; then final+=("$svc"); continue; fi
        if team_in_list "$svc" "${optional[@]}" && ! team_image_exists_for_service "$svc"; then
            echo "Skipping optional $svc (image not found)"; continue
        fi
        if ! team_image_exists_for_service "$svc"; then
            echo "Skipping $svc (image not found — run build first)"; continue
        fi
        final+=("$svc")
    done
    printf '%s\n' "${final[@]}"
}

team_expand_url() {
    local line="$1"
    line="${line//\$\{API_GATEWAY_PORT:-5100\}/${API_GATEWAY_PORT:-5100}}"
    eval "echo \"$line\""
}

team_cmd_start() {
    local team_id="$1" display="${TEAM_YAML_DISPLAY:-$team_id}"
    local -a services=() phase_names=() rest=() phased=()
    local pidx pi p_args wait line
    if [[ "$TEAM_YAML_SERVICES_MODE" == "all" ]]; then
        echo "Starting $display (all compose services)..."
        team_run docker compose -f "$TEAM_COMPOSE_FILE" up -d --no-build
    else
        mapfile -t services < <(team_resolve_services)
        mapfile -t services < <(team_filter_start_services "${services[@]}")
        ((${#services[@]} == 0)) && fatal "No services to start"
        echo "Starting $display: ${services[*]}"
        if (( TEAM_START_PHASE_COUNT > 0 )); then
            for ((pidx=0; pidx<TEAM_START_PHASE_COUNT; pidx++)); do
                local -n _phase="TEAM_START_PHASE_${pidx}"
                phase_names=()
                for pi in "${_phase[@]}"; do
                    team_in_list "$pi" "${services[@]}" && phase_names+=("$pi")
                done
                ((${#phase_names[@]} == 0)) && continue
                echo "Phase: ${phase_names[*]}"
                p_args=(docker compose -f "$TEAM_COMPOSE_FILE" up -d --no-build)
                if [[ "$TEAM_START_NO_DEPS" == "true" && $pidx -gt 0 ]]; then
                    p_args+=(--no-deps)
                fi
                team_run "${p_args[@]}" "${phase_names[@]}"
                wait="${TEAM_START_PHASE_WAIT:-0}"
                if (( pidx == 0 && wait > 0 )); then
                    echo "Waiting ${wait}s for infrastructure..."
                    sleep "$wait"
                fi
            done
            for pi in "${services[@]}"; do
                local found=0 p j
                for ((pidx=0; pidx<TEAM_START_PHASE_COUNT; pidx++)); do
                    local -n _ph="TEAM_START_PHASE_${pidx}"
                    for p in "${_ph[@]}"; do [[ "$p" == "$pi" ]] && found=1 && break; done
                    (( found )) && break
                done
                (( found )) || rest+=("$pi")
            done
            if ((${#rest[@]} > 0)); then
                p_args=(docker compose -f "$TEAM_COMPOSE_FILE" up -d --no-build)
                [[ "$TEAM_START_NO_DEPS" == "true" ]] && p_args+=(--no-deps)
                team_run "${p_args[@]}" "${rest[@]}"
            fi
        else
            local -a args=(docker compose -f "$TEAM_COMPOSE_FILE" up -d --no-build)
            [[ "$TEAM_START_NO_DEPS" == "true" ]] && args+=(--no-deps)
            team_run "${args[@]}" "${services[@]}"
        fi
    fi
    echo "$display services started"
    for line in "${TEAM_YAML_URLS[@]}"; do team_expand_url "$line"; done
}

team_cmd_stop() {
    local team_id="$1" remove="${2:-0}"
    local display="${TEAM_YAML_DISPLAY:-$team_id}"
    local -a services=()
    mapfile -t services < <(team_resolve_services)
    echo "Stopping $display..."
    if [[ "$TEAM_YAML_SERVICES_MODE" == "all" ]]; then
        team_run --no-check docker compose -f "$TEAM_COMPOSE_FILE" stop
        (( remove )) && team_run --no-check docker compose -f "$TEAM_COMPOSE_FILE" rm -f
    elif ((${#services[@]} > 0)); then
        team_run --no-check docker compose -f "$TEAM_COMPOSE_FILE" stop "${services[@]}"
        (( remove )) && team_run --no-check docker compose -f "$TEAM_COMPOSE_FILE" rm -f "${services[@]}"
    fi
    if (( remove )); then echo "$display services stopped and removed"
    else echo "$display services stopped"; fi
}

team_cmd_restart() {
    team_cmd_stop "$1" 0
    team_cmd_start "$1"
}

team_cmd_show() {
    local team_id="$1" display="${TEAM_YAML_DISPLAY:-$team_id}"
    local -a services=() subs=()
    mapfile -t services < <(team_resolve_services)
    mapfile -t subs < <(team_resolve_submodules)
    echo "id: ${TEAM_YAML_ID:-$team_id}"
    echo "display: $display"
    echo "services (${#services[@]}):"
    local s; for s in "${services[@]}"; do echo "  - $s"; done
    echo "submodules (${#subs[@]}):"
    local sm; for sm in "${subs[@]}"; do echo "  - $sm"; done
}

team_cmd_list_teams() { team_list_ids; }

team_ops() {
    local cmd="${1:-}" team="${2:-}" yml team_id root
    root="$(team_repo_root)"
    case "$cmd" in
        list-teams) team_cmd_list_teams; return 0 ;;
        pull|build|start|stop|stop-rm|restart|show) ;;
        *) fatal "Unknown team_ops command: $cmd" ;;
    esac
    [[ -n "$team" ]] || { print_ops_usage; fatal "Missing team argument"; }
    yml="$(team_resolve_yml "$team")" || exit 1
    team_yaml_load "$yml"
    team_id="${TEAM_YAML_ID:-$(basename "$yml" .yml)}"
    cd "$root" || fatal "Cannot cd to $root"
    case "$cmd" in
        pull) team_cmd_pull "$team_id" ;;
        build) team_cmd_build "$team_id" ;;
        start) team_cmd_start "$team_id" ;;
        stop) team_cmd_stop "$team_id" 0 ;;
        stop-rm) team_cmd_stop "$team_id" 1 ;;
        restart) team_cmd_restart "$team_id" ;;
        show) team_cmd_show "$team_id" ;;
    esac
}

pull_submodules() {
    step "Pulling team submodules ($TEAM_DISPLAY) via teams/$TEAM_FOLDER.yml"
    team_ops pull "$TEAM_FOLDER"
    ok "Submodules pulled for $TEAM_DISPLAY"
}

build_and_start_team_env() {
    step "Building & starting $TEAM_DISPLAY (teams/$TEAM_FOLDER.yml)"
    info "build (may take a while)"
    team_ops build "$TEAM_FOLDER"
    info "start"
    team_ops start "$TEAM_FOLDER"
    ok "Containers are starting"
    info "docker ps -- currently running containers:"
    docker ps --format "    {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -40
}

print_ops_usage() {
    cat <<EOF
Usage:
  $0                          Interactive onboard (clone, pull, build, start, seed)
  $0 pull|build|build-nc|start|stop|stop-rm|restart|show <team>
  $0 list-teams

Teams (see teams/*.yml):
  ai-team  backend-team  frontend-team  infrastructure-team
  ml-team  platform-engineers  qa-team
  Short aliases: ai backend frontend infra ml platform qa all

QA tiers (PR #301) — preferred for QA; mirrors eng team YAMLs:
  qa-tier-1 / qa:1  →  frontend-team
  qa-tier-2 / qa:2  →  backend-team
  qa-tier-3 / qa:3  →  ai-team
EOF
}

# ---------- DB seeding ----------------------------------------------------
# Schema scripts (postgres-init-*.sql) are auto-loaded by the postgres image
# via /docker-entrypoint-initdb.d on first volume creation. The SEED data
# (postgres-seed.sql) is NOT auto-mounted, so we apply it here once the
# postgres-core container is healthy. This is what the markdown's
# "seeding in the init scripts in the databases (if they're not already
# automatically initialized in the docker file / docker compose)" refers to.
seed_databases() {
    step "Seeding databases (init scripts)"
    local seed_sql="$PLATFORM_REPO_DIR/scripts/database/postgres-seed.sql"
    if [[ ! -f "$seed_sql" ]]; then
        warn "$seed_sql not found -- nothing to seed"
        return
    fi

    local container="deepiri-postgres-core-dev"
    local user="${POSTGRES_CORE_USER:-deepiri}"
    local db="${POSTGRES_CORE_DB:-deepiri}"

    if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
        warn "$container is not running -- skipping seed"
        warn "Once it is up, you can run:"
        warn "  docker exec -i $container psql -U $user -d $db < scripts/database/postgres-seed.sql"
        return
    fi

    info "Waiting for postgres-core to accept connections..."
    local i
    for i in $(seq 1 60); do
        if docker exec "$container" pg_isready -U "$user" -d "$db" \
                >/dev/null 2>&1; then
            ok "postgres-core is ready"
            break
        fi
        sleep 2
        if (( i == 60 )); then
            warn "postgres-core did not become ready in 120s -- skipping seed"
            return
        fi
    done

    info "Applying scripts/database/postgres-seed.sql to $db on $container"
    if docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U "$user" -d "$db" \
            < "$seed_sql"; then
        ok "Seed data applied"
    else
        warn "Seed application reported errors (some objects may not exist yet)."
        warn "You can re-run later with:"
        warn "  docker exec -i $container psql -U $user -d $db < scripts/database/postgres-seed.sql"
    fi
}

# ---------- summary -------------------------------------------------------
print_summary() {
    step "All done!"
    local qa_note=""
    if [[ -n "$QA_TIER" ]]; then
        qa_note="
  ${C_BOLD}QA tier:${C_RESET}         $QA_TIER → teams/$TEAM_FOLDER.yml (mirrors that eng team)
"
        if [[ "$QA_TIER" == "3" ]]; then
            qa_note+="  ${C_CYAN}Tip:${C_RESET} Tier 3 can also run frontend-team or backend-team envs if needed.
"
        fi
    fi
    cat <<EOF
  ${C_BOLD}Team:${C_RESET}            $TEAM_DISPLAY
  ${C_BOLD}Team config:${C_RESET}      teams/$TEAM_FOLDER.yml
${qa_note}  ${C_BOLD}Project root:${C_RESET}    $PROJECT_ROOT
  ${C_BOLD}Platform repo:${C_RESET}   $PLATFORM_REPO_DIR

  Useful commands (run from $PLATFORM_REPO_DIR):
    docker ps
    docker compose -f docker-compose.dev.yml logs -f api-gateway
    ./setup-deepiri-dev.sh stop $TEAM_FOLDER
    ./setup-deepiri-dev.sh show $TEAM_FOLDER

  ${C_YELLOW}Speech engine:${C_RESET} livekit + speech in teams/ai-team.yml (QA Tier 3).
    Docs: docs/architecture/DEEPIRI_SPEECH_INTEGRATION.md
    Media = WebRTC via LiveKit — not Socket.IO / realtime-gateway.

  ${C_YELLOW}Reminder:${C_RESET} drop your /secrets folder into
    $PLATFORM_REPO_DIR/ops/k8s/secrets
  before any service that needs them will start cleanly.

  Next up: Sign up and check for tasks on the Plaky board. Go to #kanban on Discord for instructions.
EOF
}

# ---------- main ----------------------------------------------------------
OPS_COMMANDS="pull|build|build-nc|start|stop|stop-rm|restart|show|list-teams|help|-h|--help"

run_ops_command() {
    local cmd="$1"
    shift || true
    case "$cmd" in
        help|-h|--help)
            print_ops_usage
            exit 0
            ;;
        list-teams)
            PLATFORM_REPO_DIR="${PLATFORM_REPO_DIR:-$SCRIPT_DIR}"
            team_ops list-teams
            exit 0
            ;;
        pull|build|build-nc|start|stop|stop-rm|restart|show)
            local team="${1:-}"
            [[ -n "$team" ]] || { print_ops_usage; fatal "Missing team argument"; }
            if [[ "$cmd" == "build-nc" ]]; then
                cmd="build"
                TEAM_BUILD_NO_CACHE=1
            fi
            if [[ -f "$SCRIPT_DIR/teams/all-services.yml" ]]; then
                PLATFORM_REPO_DIR="$SCRIPT_DIR"
            elif [[ -f "$SCRIPT_DIR/../teams/all-services.yml" ]]; then
                PLATFORM_REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
            else
                PLATFORM_REPO_DIR="${PLATFORM_REPO_DIR:-$SCRIPT_DIR}"
            fi
            team_ops "$cmd" "$team"
            exit $?
            ;;
        *)
            fatal "Unknown command: $cmd"
            ;;
    esac
}

main_onboard() {
    step "Deepiri Platform :: dev environment setup"
    detect_platform
    info "OS: $OS_KIND  distro: ${DISTRO_ID:-n/a}  pkg: ${PKG_MANAGER:-n/a}"
    require_debian_on_wsl_or_linux
    [[ "$OS_KIND" != "unsupported" ]] \
        || fatal "Unsupported OS: $(uname -s). This script targets macOS, Debian Linux, and Debian WSL2."

    detect_existing_clone
    select_team
    # QA tiers (PR #301): TEAM_FOLDER is already remapped to frontend/backend/ai
    if [[ -n "$QA_TIER" ]]; then
        info "QA Tier $QA_TIER → teams/$TEAM_FOLDER.yml (same as that eng team)"
    fi
    ensure_prereqs
    ensure_ssh_key_for_github
    choose_project_dir
    clone_platform_repo
    pull_submodules
    build_and_start_team_env
    seed_databases
    print_summary
}

main() {
    if [[ $# -gt 0 ]]; then
        if [[ "$1" =~ ^($OPS_COMMANDS)$ ]]; then
            run_ops_command "$@"
        else
            print_ops_usage
            fatal "Unknown argument: $1 (onboard takes no args; use pull|build|start|…)"
        fi
    fi
    main_onboard
}

main "$@"
