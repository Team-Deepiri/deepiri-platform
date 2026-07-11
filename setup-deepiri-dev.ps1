# ============================================================================
# Deepiri Platform - Automated Development Environment Setup (Windows)
# ----------------------------------------------------------------------------
# PowerShell counterpart to setup-deepiri-dev.sh. Handles team + hardware-tier
# selection, submodule init, and docker startup on Windows (native PowerShell,
# no WSL required for the orchestration itself — Docker Desktop provides the
# engine).
#
# Mirrors the bash script's behavior on Windows: auto-installs prerequisites
# via winget (git, Docker Desktop, python, node), sets up an SSH key, and runs
# the same team/tier/submodule/docker orchestration.
#
# Usage:
#   .\setup-deepiri-dev.ps1 [-Team <team>] [-Tier <1|2|3>]
#                           [-SkipSubmodules] [-SkipDocker] [-Build]
#                           [-UpdateSubmodules] [-NonInteractive]
#
# Submodule policy:
#   Fresh / uninitialized submodules are pulled at the latest branch tip.
#   Already-initialized submodules are left exactly as they are.
#   Pass -UpdateSubmodules to force every submodule to the latest.
# ============================================================================

param(
    [string]$Team = "",
    [string]$Tier = "",
    [switch]$SkipSubmodules,
    [switch]$SkipDocker,
    [switch]$Build,
    [switch]$UpdateSubmodules,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Find repo root via git (script may live at root or in scripts/dev-setup/).
# The parent repo is not listed in its own .gitmodules, so we ask git for the
# working-tree root instead of grepping that file.
function Find-RepoRoot {
    Push-Location $PSScriptRoot
    try {
        $toplevel = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $toplevel) {
            return $toplevel.Trim()
        }
    } catch { }
    finally { Pop-Location }
    return $PSScriptRoot
}

$RepoRoot = Find-RepoRoot
Set-Location $RepoRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Blue }
function Write-Info($msg) { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  xx  $msg" -ForegroundColor Red; exit 1 }

# In non-interactive mode we never prompt. We return the supplied default, so
# callers that would change the system (package installs, SSH keygen) pass "N"
# and are skipped rather than silently auto-approved.
function Confirm-Prompt($prompt, $default = "Y") {
    if ($NonInteractive) { return ($default -match "^[Yy]$") }
    $suffix = if ($default -match "^[Yy]$") { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "  ?? $prompt $suffix"
    if ($answer -eq "") { $answer = $default }
    return ($answer -match "^[Yy]$")
}

Write-Step "Deepiri Platform :: dev environment setup (Windows)"

# ---------- team selection ------------------------------------------------
$TeamsDisplay = @("AI", "Backend", "Frontend", "Infrastructure", "ML", "Platform", "QA", "Cyrex")
$TeamsKey     = @("ai", "backend", "frontend", "infrastructure", "ml", "platform", "qa", "cyrex")

$TeamKey = ""
$TeamDisplay = ""

if ($Team -ne "") {
    $TeamKey = $Team.ToLower()
    if ($TeamsKey -notcontains $TeamKey) { Write-Err "Unknown team: $Team" }
    $idx = [array]::IndexOf($TeamsKey, $TeamKey)
    $TeamDisplay = $TeamsDisplay[$idx]
    Write-Ok "Team: $TeamDisplay"
} else {
    Write-Step "Which team are you on?"
    for ($i = 0; $i -lt $TeamsDisplay.Count; $i++) {
        Write-Host ("    {0}) {1}" -f ($i + 1), $TeamsDisplay[$i])
    }
    while ($true) {
        $choice = Read-Host "  ?? Enter a number [1-$($TeamsDisplay.Count)]"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $TeamsDisplay.Count) {
            $TeamDisplay = $TeamsDisplay[[int]$choice - 1]
            $TeamKey = $TeamsKey[[int]$choice - 1]
            Write-Ok "Selected: $TeamDisplay"
            break
        }
        Write-Warn "Invalid selection. Try again."
    }
}

# ---------- hardware detection --------------------------------------------
Write-Step "Detecting hardware"
$RamGB = 0; $Gpu = "none"

try {
    $RamBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $RamGB = [math]::Round($RamBytes / 1GB)
} catch { Write-Warn "Could not detect RAM" }

try {
    $GpuName = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    if ($GpuName -match "NVIDIA") { $Gpu = "nvidia" }
    elseif ($GpuName -match "AMD|Radeon") {
        $VramMB = [math]::Round((Get-CimInstance Win32_VideoController | Select-Object -First 1).AdapterRAM / 1MB)
        $Gpu = if ($VramMB -gt 1024) { "amd" } else { "amd-integrated" }
    }
} catch { Write-Warn "Could not detect GPU" }

Write-Info "RAM: ${RamGB}GB  |  GPU: $Gpu"

# ---------- tier selection ------------------------------------------------
Write-Step "Selecting hardware tier"
if ($Tier -eq "") {
    $suggested = if (($Gpu -eq "nvidia" -or $Gpu -eq "amd") -and $RamGB -ge 16) { "1" }
                 elseif ($RamGB -ge 16) { "2" }
                 else { "3" }
    Write-Host ""
    Write-Host "  T1 - GPU + 16GB+  : Full stack (best for local LLM / Ollama)"
    Write-Host "  T2 - No GPU, 16GB+: Full stack"
    Write-Host "  T3 - <16GB        : Core only"
    Write-Host ""
    Write-Info "Detected hardware suggests Tier $suggested"
    if ($NonInteractive) {
        $Tier = $suggested
    } else {
        $input = Read-Host "  ?? Press Enter for Tier $suggested, or type 1/2/3"
        $Tier = if ($input -eq "") { $suggested } else { $input }
    }
}
switch ($Tier) {
    "1" { Write-Ok "Tier 1 - Full stack (GPU present)" }
    "2" { Write-Ok "Tier 2 - Full stack (no GPU)" }
    "3" { Write-Ok "Tier 3 - Core services only" }
    default { Write-Err "Invalid tier: $Tier" }
}

# ---------- prereq install (winget, Windows) ------------------------------
Write-Step "Checking prerequisites"

$WingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if (-not $WingetAvailable) {
    Write-Warn "winget not found -- cannot auto-install. Install tools manually if any are missing."
}

# tool check-command -> winget package id
$PrereqMap = @(
    @{ Cmd = "git";    Id = "Git.Git" },
    @{ Cmd = "docker"; Id = "Docker.DockerDesktop" },
    @{ Cmd = "python"; Id = "Python.Python.3.12" },
    @{ Cmd = "node";   Id = "OpenJS.NodeJS" }
)

$InstalledSomething = $false
foreach ($p in $PrereqMap) {
    if (Get-Command $p.Cmd -ErrorAction SilentlyContinue) {
        Write-Ok "$($p.Cmd) found"
    } elseif ($WingetAvailable) {
        Write-Warn "$($p.Cmd) is missing."
        $installDefault = if ($NonInteractive) { "N" } else { "Y" }
        if (Confirm-Prompt "Install $($p.Cmd) via winget ($($p.Id))?" $installDefault) {
            winget install --id $($p.Id) --silent --accept-package-agreements --accept-source-agreements
            $InstalledSomething = $true
        } else {
            Write-Warn "Skipped $($p.Cmd) -- install it manually before running services"
        }
    } else {
        Write-Warn "$($p.Cmd) missing and winget unavailable -- install manually"
    }
}

if ($InstalledSomething) {
    Write-Warn "One or more tools were just installed. If commands are not found below,"
    Write-Warn "close and reopen PowerShell (to refresh PATH), then re-run this script."
}

# Docker Desktop needs to be running, not just installed.
# After a fresh winget install, the docker command may not be on PATH yet.
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker info *>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Docker is installed but not running. Start Docker Desktop, wait for 'Engine running', then re-run."
    } else {
        Write-Ok "Docker daemon reachable"
    }
} else {
    Write-Warn "Docker not on PATH yet (likely just installed). Reopen PowerShell and re-run."
}

# ---------- SSH key check -------------------------------------------------
Write-Step "Checking GitHub SSH access"
if ($NonInteractive) {
    Write-Warn "Non-interactive mode -- skipping SSH key setup"
} else {
$sshKey = "$HOME\.ssh\id_ed25519"
if (-not (Test-Path $sshKey) -and -not (Test-Path "$HOME\.ssh\id_rsa")) {
    Write-Warn "No SSH key found in ~\.ssh"
    if (Confirm-Prompt "Generate a new ed25519 SSH key now?" "Y") {
        $email = Read-Host "  ?? Email for the SSH key"
        if ($email -eq "") { $email = "deepiri-dev@$env:COMPUTERNAME" }
        ssh-keygen -t ed25519 -C "$email" -f "$sshKey" -N '""'
        Write-Ok "Created $sshKey"
    }
}
if (Test-Path "$sshKey.pub") {
    Write-Host ""
    Write-Host "  Add this public key to GitHub (https://github.com/settings/ssh/new):"
    Write-Host "  ----------------------------------------------------------------"
    Get-Content "$sshKey.pub" | ForEach-Object { Write-Host "    $_" }
    Write-Host "  ----------------------------------------------------------------"
    Get-Content "$sshKey.pub" | Set-Clipboard
    Write-Info "Public key copied to clipboard"
}
}

# ---------- submodules ----------------------------------------------------
# Submodule policy:
#   - Fresh / not yet initialized  -> init AND bump to the latest branch tip.
#   - Already initialized          -> leave it exactly as-is (do not touch).
#   - -UpdateSubmodules passed     -> force-bump every submodule to latest.
function Initialize-Submodule($path) {
    # Clean up a stale directory that is not a valid submodule.
    if ((Test-Path $path) -and -not (Test-Path "$path/.git")) {
        Write-Warn "Cleaning invalid directory at $path"
        Remove-Item -Recurse -Force $path
    }

    $wasInitialized = Test-Path "$path/.git"

    if ($wasInitialized -and -not $UpdateSubmodules) {
        Write-Ok "$path (already initialized - left as-is)"
        return
    }

    if ($wasInitialized) {
        Write-Info "Updating $path to latest (-UpdateSubmodules)..."
    } else {
        Write-Info "Initializing $path (fresh - will pull latest)..."
    }

    git submodule update --init --recursive $path 2>&1 | Out-Null
    if (-not (Test-Path $path)) {
        Write-Warn "Could not init $path - check SSH key / GitHub access"
        return
    }

    Push-Location $path
    git fetch origin 2>$null
    $branch = if ($path -match "deepiri-synapse|deepiri-sugar-glider") { "dev" } else { "main" }
    $exists = git show-ref --verify "refs/remotes/origin/$branch" 2>$null
    if (-not $exists) { $branch = "master" }
    $headRef = git symbolic-ref -q HEAD 2>$null
    if (-not $headRef) { git checkout -B $branch "origin/$branch" 2>$null }
    git pull origin $branch 2>$null
    Pop-Location
    Write-Ok "$path (at latest $branch)"
}

if (-not $SkipSubmodules) {
    Write-Step "Initializing submodules ($TeamDisplay)"

    if ($UpdateSubmodules) {
        Write-Info "Policy: -UpdateSubmodules - every submodule will be bumped to the latest branch tip"
    } else {
        Write-Info "Policy: fresh submodules get the latest; already-initialized ones are left untouched"
        Write-Info "        (use -UpdateSubmodules to force-pull the latest for all)"
    }

    # deepiri-suite provides the Docker base images; it follows the same policy.
    Initialize-Submodule "deepiri-suite"

    $Shared = @(
        "platform-services/shared/deepiri-prismpipe",
        "platform-services/shared/deepiri-shared-utils",
        "platform-services/shared/deepiri-synapse",
        "platform-services/shared/deepiri-sugar-glider"
    )
    $Backend = @(
        "platform-services/backend/deepiri-api-gateway",
        "platform-services/backend/deepiri-auth-service",
        "platform-services/backend/deepiri-external-bridge-service",
        "platform-services/backend/deepiri-language-intelligence-service",
        "deepiri-web-frontend"
    )

    $AllSubs = $false
    $Subs = switch ($TeamKey) {
        "cyrex"          { @("diri-cyrex", "deepiri-modelkit") + $Shared }
        "ai"             { @("diri-cyrex", "deepiri-ollama-utils", "deepiri-modelkit", "platform-services/backend/deepiri-api-gateway") + $Shared }
        "ml"             { @("diri-helox", "deepiri-modelkit", "deepiri-ollama-utils") + $Shared }
        "backend"        { $Backend + $Shared }
        "infrastructure" { $Backend + $Shared }
        "frontend"       { @("deepiri-web-frontend", "platform-services/backend/deepiri-api-gateway", "platform-services/backend/deepiri-auth-service") + $Shared }
        "platform"       { $AllSubs = $true; @() }
        "qa"             { @(
                            "platform-services/shared/deepiri-synapse",
                            "platform-services/shared/deepiri-sugar-glider",
                            "platform-services/shared/deepiri-shared-utils",
                            "platform-services/shared/deepiri-prismpipe",
                            "platform-services/backend/deepiri-auth-service",
                            "platform-services/backend/deepiri-external-bridge-service",
                            "platform-services/backend/deepiri-api-gateway",
                            "platform-services/backend/deepiri-language-intelligence-service",
                            "deepiri-web-frontend",
                            "deepiri-ollama-utils"
                        ) }
    }

    if ($AllSubs) {
        Write-Info "Platform team: all submodules"
        # Apply the same policy per-submodule rather than a blanket update, so
        # already-initialized submodules are left untouched.
        $allPaths = git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | ForEach-Object { ($_ -split '\s+')[1] }
        foreach ($sub in $allPaths) { if ($sub) { Initialize-Submodule $sub } }
        Write-Ok "All submodules ready"
    } else {
        foreach ($sub in ($Subs | Select-Object -Unique)) { Initialize-Submodule $sub }
        Write-Ok "Submodules ready for $TeamDisplay"
    }
} else {
    Write-Warn "Skipping submodules (-SkipSubmodules)"
}

# ---------- docker --------------------------------------------------------
if (-not $SkipDocker) {
    Write-Step "Starting Docker services ($TeamDisplay, Tier $Tier)"

    $dockerCheck = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Err "Docker is not running. Start Docker Desktop and try again." }

    $buildFlag = if ($Build) { "" } else { "--no-build" }

    $AI = "postgres redis influxdb etcd minio milvus cyrex cyrex-interface mlflow challenge-service api-gateway messaging-service realtime-gateway synapse sugar-glider"
    $ML = "synapse sugar-glider"
    $BackendInfra = "postgres-auth postgres-core postgres-intelligence redis influxdb api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway language-intelligence-service messaging-service frontend-dev synapse sugar-glider adminer"
    $Frontend = "frontend-dev api-gateway auth-service communications-hub messaging-service realtime-gateway postgres-auth postgres-core postgres-intelligence"
    $Cyrex = "postgres redis postgres-cyrex cyrex cyrex-interface api-gateway"
    $QaInfra = "postgres-auth postgres-core postgres-intelligence redis influxdb synapse sugar-glider"
    $QaBackend = "api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway adminer"
    $QaAll = "$QaInfra kafka $QaBackend language-intelligence-service messaging-service frontend-dev"

    $buildArgs = if ($buildFlag -eq "") { @() } else { @($buildFlag) }

    if ($Tier -eq "3") {
        Write-Warn "Tier 3: core services only"
        docker compose -f docker-compose.dev.yml up -d @buildArgs --no-deps postgres-auth postgres-core redis api-gateway auth-service
    } elseif ($TeamKey -eq "platform") {
        Write-Info "Platform team: starting all services..."
        docker compose -f docker-compose.dev.yml up -d @buildArgs
    } elseif ($TeamKey -eq "qa") {
        Write-Info "QA team: staged startup..."
        $arr = $QaInfra -split '\s+'
        docker compose -f docker-compose.dev.yml up -d @buildArgs @arr
        Write-Info "Waiting 3s for infrastructure..."; Start-Sleep -Seconds 3
        $arr = $QaBackend -split '\s+'
        docker compose -f docker-compose.dev.yml up -d @buildArgs --no-deps @arr
        $arr = ($QaAll -split '\s+' | Select-Object -Unique)
        docker compose -f docker-compose.dev.yml up -d @buildArgs --no-deps @arr
    } else {
        $services = switch ($TeamKey) {
            "cyrex"          { $Cyrex }
            "ai"             { "$AI ollama" }   # Windows/WSL runs ollama in Docker (MPS is Mac-only, AI team only)
            "ml"             { $ML }
            "backend"        { $BackendInfra }
            "infrastructure" { $BackendInfra }
            "frontend"       { $Frontend }
        }
        $arr = ($services -split '\s+' | Where-Object { $_ -ne "" } | Select-Object -Unique)
        Write-Info "Services: $($arr -join ' ')"
        docker compose -f docker-compose.dev.yml up -d @buildArgs --no-deps @arr
    }

    Write-Ok "Services started"
} else {
    Write-Warn "Skipping Docker (-SkipDocker)"
}

# ---------- summary -------------------------------------------------------
Write-Step "All done!"
Write-Host ""
Write-Host "  Team:          $TeamDisplay"
Write-Host "  Tier:          $Tier"
Write-Host "  Hardware:      ${RamGB}GB RAM, GPU: $Gpu"
Write-Host ""
Write-Host "  Endpoints:"
Write-Host "    API Gateway:     http://localhost:5100"
Write-Host "    Cyrex:           http://localhost:8000"
Write-Host "    Cyrex Interface: http://localhost:5175"
Write-Host "    MLflow:          http://localhost:5500"
Write-Host "    Frontend:        http://localhost:5173"
Write-Host "    Synapse:         http://localhost:8002"
if ($TeamKey -eq "ai" -and $Tier -ne "3") { Write-Host "    Ollama:          http://localhost:11434" }
Write-Host ""
Write-Host "  Commands:"
Write-Host "    Logs:   docker compose -f docker-compose.dev.yml logs -f <service>"
Write-Host "    Status: docker compose -f docker-compose.dev.yml ps"
Write-Host "    Stop:   docker compose -f docker-compose.dev.yml down"
Write-Host ""
Write-Host "  Next up: check Plaky for tasks. See #kanban on Discord."
