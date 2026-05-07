#!/usr/bin/env bash
# ============================================================================
# Deepiri Platform - Automated Development Environment Setup
# ----------------------------------------------------------------------------
# Automates the steps documented in deepiri-environment-setup.md:
#
#   1. Asks which team you're on (AI / Backend / Frontend / Infrastructure /
#      ML / Platform / QA).
#   2. Verifies prerequisites (git, docker, docker compose, python3, node, npm,
#      ssh) and installs anything missing. WSL2/Linux must be Debian — the
#      script refuses to continue otherwise.
#   3. Asks where you want the Deepiri project folder to live (default ~).
#   4. Clones deepiri-platform (if not already cloned), runs the team's
#      pull_submodules.sh, then build.sh + start.sh in
#      team_dev_environments/<team>/.
#   5. Seeds the Postgres core DB with scripts/database/postgres-seed.sql
#      after the auto-init schema scripts have run via
#      /docker-entrypoint-initdb.d.
#
# Usage: bash setup-deepiri-dev.sh
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
            ok "Selected: $TEAM_DISPLAY ($TEAM_FOLDER)"
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

    info "Ensuring pyyaml is available (needed by team_dev_environments/run.py)"
    if ! python3 -c "import yaml" >/dev/null 2>&1; then
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install --user --quiet pyyaml || warn "pip install pyyaml failed (non-fatal)"
        fi
    fi
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
    if [[ -f "$script_dir/.gitmodules" ]] \
       && grep -q "Team-Deepiri/deepiri-platform\|Team-Deepiri/deepiri-core-api" \
                  "$script_dir/.gitmodules" 2>/dev/null; then
        EXISTING_CLONE="$script_dir"
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

# ---------- submodules + build/start --------------------------------------
pull_submodules() {
    step "Pulling team submodules ($TEAM_DISPLAY)"
    local script="$PLATFORM_REPO_DIR/team_submodule_commands/$TEAM_FOLDER/pull_submodules.sh"
    [[ -f "$script" ]] || fatal "pull_submodules.sh not found at $script"
    chmod +x "$script"
    ( cd "$PLATFORM_REPO_DIR" && bash "$script" )
    ok "Submodules pulled for $TEAM_DISPLAY"
}

build_and_start_team_env() {
    step "Building & starting $TEAM_DISPLAY dev environment"
    local team_env_dir="$PLATFORM_REPO_DIR/team_dev_environments/$TEAM_FOLDER"
    [[ -d "$team_env_dir" ]] || fatal "Team env folder missing: $team_env_dir"

    chmod +x "$team_env_dir/build.sh" "$team_env_dir/start.sh" "$team_env_dir/stop.sh"
    ok "Made build.sh / start.sh / stop.sh executable"

    info "Running build.sh (this can take a while -- legacy Docker builder is used)"
    ( cd "$team_env_dir" && ./build.sh )

    info "Running start.sh"
    ( cd "$team_env_dir" && ./start.sh )

    ok "Containers are starting"
    info "docker ps -- currently running containers:"
    docker ps --format "    {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -40
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
    cat <<EOF
  ${C_BOLD}Team:${C_RESET}            $TEAM_DISPLAY
  ${C_BOLD}Project root:${C_RESET}    $PROJECT_ROOT
  ${C_BOLD}Platform repo:${C_RESET}   $PLATFORM_REPO_DIR

  Useful commands (run from $PLATFORM_REPO_DIR):
    docker ps
    docker compose -f docker-compose.dev.yml logs -f api-gateway
    cd team_dev_environments/$TEAM_FOLDER && ./stop.sh

  ${C_YELLOW}Reminder:${C_RESET} drop your /secrets folder into
    $PLATFORM_REPO_DIR/ops/k8s/secrets
  before any service that needs them will start cleanly.

  Next up: Sign up and check for tasks on the Plaky board. Go to #kanban on Discord for instructions.
EOF
}

# ---------- main ----------------------------------------------------------
main() {
    step "Deepiri Platform :: dev environment setup"
    detect_platform
    info "OS: $OS_KIND  distro: ${DISTRO_ID:-n/a}  pkg: ${PKG_MANAGER:-n/a}"
    require_debian_on_wsl_or_linux
    [[ "$OS_KIND" != "unsupported" ]] \
        || fatal "Unsupported OS: $(uname -s). This script targets macOS, Debian Linux, and Debian WSL2."

    detect_existing_clone
    select_team
    ensure_prereqs
    ensure_ssh_key_for_github
    choose_project_dir
    clone_platform_repo
    pull_submodules
    build_and_start_team_env
    seed_databases
    print_summary
}

main "$@"
