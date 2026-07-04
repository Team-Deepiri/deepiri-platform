# =============================================================================
# Deepiri Unified Dev Setup (Windows/PowerShell)
# Replaces: team_dev_environments\ + team_submodule_commands\
# Usage: .\scripts\dev-setup\setup.ps1 [-Team <team>] [-Tier <1|2|3>] [-SkipSubmodules] [-SkipDocker]
# =============================================================================

param(
    [string]$Team = "",
    [string]$Tier = "",
    [switch]$SkipSubmodules,
    [switch]$SkipDocker,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $RepoRoot

function Write-Header($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-Ok($msg)     { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn($msg)   { Write-Host "  WARN  $msg" -ForegroundColor Yellow }
function Write-Info($msg)   { Write-Host "  $msg" }
function Write-Err($msg)    { Write-Host "  ERR  $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   Deepiri Unified Dev Setup (Windows)   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Step 1: Hardware detection
# -----------------------------------------------------------------------------
Write-Header "Step 1/4 - Hardware Detection"

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

# -----------------------------------------------------------------------------
# Step 2: Tier selection
# -----------------------------------------------------------------------------
Write-Header "Step 2/4 - Tier Selection"

if ($Tier -eq "") {
    $SuggestedTier = if (($Gpu -eq "nvidia" -or $Gpu -eq "amd") -and $RamGB -ge 16) { "1" }
                     elseif ($RamGB -ge 16) { "2" }
                     else { "3" }

    Write-Host ""
    Write-Host "  Detected hardware suggests Tier $SuggestedTier:" -ForegroundColor White
    Write-Host ""
    Write-Host "  T1 - GPU + 16GB+  : Full stack including Ollama"
    Write-Host "  T2 - No GPU, 16GB+: All services except Ollama  <-- your machine (32GB, integrated GPU)"
    Write-Host "  T3 - <16GB        : Core only (postgres, redis, api-gateway, auth)"
    Write-Host ""

    if ($NonInteractive) {
        $Tier = $SuggestedTier
    } else {
        $TierInput = Read-Host "  Press Enter for Tier $SuggestedTier, or type 1/2/3 to override"
        $Tier = if ($TierInput -eq "") { $SuggestedTier } else { $TierInput }
    }
}

switch ($Tier) {
    "1" { Write-Ok "Tier 1 - Full stack with Ollama" }
    "2" { Write-Ok "Tier 2 - Full stack, no Ollama" }
    "3" { Write-Ok "Tier 3 - Core services only" }
    default { Write-Err "Invalid tier: $Tier" }
}

# -----------------------------------------------------------------------------
# Step 3: Team selection
# -----------------------------------------------------------------------------
Write-Header "Step 3/4 - Team Selection"

$ValidTeams = @("ai", "ml", "backend", "frontend", "infrastructure", "cyrex", "platform", "qa")

if ($Team -eq "") {
    Write-Host ""
    Write-Host "  Teams:"
    Write-Host "    cyrex          - Cyrex AGI only"
    Write-Host "    ai             - Cyrex + MLflow + full backend + synapse"
    Write-Host "    ml             - Synapse + sugar-glider only (Helox runs natively)"
    Write-Host "    backend        - All backend microservices + infra"
    Write-Host "    frontend       - Frontend + minimal backend"
    Write-Host "    infrastructure - Same as backend (future: cloud infra)"
    Write-Host "    platform       - Everything (no service filter)"
    Write-Host "    qa             - Full backend with staged startup"
    Write-Host ""
    if ($NonInteractive) { Write-Err "Non-interactive mode requires -Team flag" }
    $Team = Read-Host "  Which team are you on?"
}

$Team = $Team.ToLower()
if ($ValidTeams -notcontains $Team) { Write-Err "Unknown team: $Team" }
Write-Ok "Team: $Team"

# -----------------------------------------------------------------------------
# Service definitions — verified from actual start.sh per team
# -----------------------------------------------------------------------------

# Verified: ai-team/start.sh
$AiServices      = "postgres redis influxdb etcd minio milvus cyrex cyrex-interface mlflow challenge-service api-gateway messaging-service realtime-gateway synapse synapse-sugar-glider"

# Verified: ml-team/start.sh
$MlServices      = "synapse synapse-sugar-glider"

# Verified: backend-team/start.sh and infrastructure-team/start.sh (identical)
$BackendInfraServices = "postgres-auth postgres-core postgres-intelligence redis influxdb api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway language-intelligence-service messaging-service frontend-dev synapse synapse-sugar-glider adminer"

# Verified: frontend-team/start.sh
$FrontendServices = "frontend-dev api-gateway auth-service communications-hub messaging-service realtime-gateway postgres-auth postgres-core postgres-intelligence"

# Cyrex minimal AGI stack
$CyrexServices   = "postgres redis postgres-cyrex cyrex cyrex-interface api-gateway"

# QA staged startup — verified: qa-team/start.sh
$QaInfra    = "postgres-auth postgres-core postgres-intelligence redis influxdb synapse synapse-sugar-glider"
$QaBackend  = "api-gateway auth-service workflow-orchestrator incentive-engine decision-intelligence communications-hub external-bridge-service adaptive-experience-engine realtime-gateway adminer"
$QaAll      = "$QaInfra kafka $QaBackend language-intelligence-service messaging-service frontend-dev"

# -----------------------------------------------------------------------------
# Submodule definitions — verified from actual pull_submodules.sh per team
# -----------------------------------------------------------------------------

$SharedSubs = @(
    "platform-services/shared/deepiri-prismpipe",
    "platform-services/shared/deepiri-shared-utils",
    "platform-services/shared/deepiri-synapse",       # branch: dev
    "platform-services/shared/deepiri-sugar-glider"   # branch: dev
)
$BackendSubs = @(
    "platform-services/backend/deepiri-api-gateway",
    "platform-services/backend/deepiri-auth-service",
    "platform-services/backend/deepiri-external-bridge-service",
    "platform-services/backend/deepiri-language-intelligence-service",
    "deepiri-web-frontend"
)

$AllSubmodules = $false
$Submodules = switch ($Team) {
    "cyrex"          { @("diri-cyrex", "deepiri-modelkit") + $SharedSubs }
    "ai"             { @("diri-cyrex", "deepiri-ollama-utils", "deepiri-modelkit", "platform-services/backend/deepiri-api-gateway") + $SharedSubs }
    "ml"             { @("diri-helox", "deepiri-modelkit", "deepiri-ollama-utils") + $SharedSubs }
    "backend"        { $BackendSubs + $SharedSubs }
    "infrastructure" { $BackendSubs + $SharedSubs }  # verified: no cyrex/helox
    "frontend"       { @("deepiri-web-frontend", "platform-services/backend/deepiri-api-gateway", "platform-services/backend/deepiri-auth-service") + $SharedSubs }
    "platform"       { $AllSubmodules = $true; @() }  # verified: git submodule update --init --recursive
    "qa"             {
        # Verified: qa-team/pull_submodules.sh
        @(
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
        )
    }
}

$Submodules = $Submodules | Select-Object -Unique

# -----------------------------------------------------------------------------
# Helper: init submodule with correct branch
# -----------------------------------------------------------------------------
function Initialize-Submodule($path) {
    Write-Info "Initializing $path..."

    if ((Test-Path $path) -and -not (Test-Path "$path/.git")) {
        Write-Warn "Cleaning invalid directory at $path"
        Remove-Item -Recurse -Force $path
    }

    git submodule update --init --recursive $path 2>&1 | Out-Null

    if (-not (Test-Path $path)) {
        Write-Warn "Could not init $path - check SSH key / GitHub access"
        return
    }

    Push-Location $path
    git fetch origin 2>$null

    # synapse and sugar-glider track dev branch per .gitmodules
    $branch = if ($path -match "deepiri-synapse|deepiri-sugar-glider") { "dev" } else { "main" }
    $exists = git show-ref --verify "refs/remotes/origin/$branch" 2>$null
    if (-not $exists) { $branch = "master" }

    $headRef = git symbolic-ref -q HEAD 2>$null
    if (-not $headRef) { git checkout -B $branch "origin/$branch" 2>$null }
    git pull origin $branch 2>$null
    Pop-Location

    Write-Ok $path
}

# -----------------------------------------------------------------------------
# Step 4a: Submodules
# -----------------------------------------------------------------------------
if (-not $SkipSubmodules) {
    Write-Header "Step 4a/4 - Initializing Submodules (team: $Team)"

    Write-Info "Initializing deepiri-suite (base images)..."
    git submodule update --init deepiri-suite 2>&1 | Out-Null
    if (Test-Path "deepiri-suite") { Write-Ok "deepiri-suite" } else { Write-Warn "deepiri-suite failed - Docker builds may fall back to GHCR" }

    if ($AllSubmodules) {
        Write-Info "Platform/QA team: initializing all submodules..."
        git submodule update --init --recursive
        Write-Ok "All submodules initialized"
    } else {
        foreach ($sub in $Submodules) { Initialize-Submodule $sub }
        Write-Ok "All submodules ready"
    }
} else {
    Write-Warn "Skipping submodules (-SkipSubmodules)"
}

# -----------------------------------------------------------------------------
# Step 4b: Docker
# -----------------------------------------------------------------------------
if (-not $SkipDocker) {
    Write-Header "Step 4b/4 - Starting Docker Services (Tier: $Tier)"

    $dockerCheck = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Err "Docker is not running. Please start Docker Desktop and try again." }

    if ($Tier -eq "3") {
        Write-Warn "Tier 3: core services only"
        docker compose -f docker-compose.dev.yml up -d --no-build --no-deps postgres-auth postgres-core redis api-gateway auth-service

    } elseif ($Team -eq "platform") {
        # Verified: platform-engineers/start.sh — no service filter
        Write-Info "Platform team: starting all services..."
        docker compose -f docker-compose.dev.yml up -d --no-build

    } elseif ($Team -eq "qa") {
        # Verified: qa-team/start.sh — staged startup
        Write-Info "QA team: staged startup..."
        Write-Info "Phase 1: infrastructure services..."
        $QaInfraArr = $QaInfra -split '\s+'
        docker compose -f docker-compose.dev.yml up -d --no-build @QaInfraArr
        Write-Info "Waiting 3s for infrastructure to be ready..."
        Start-Sleep -Seconds 3
        Write-Info "Phase 2: backend services..."
        $QaBackendArr = $QaBackend -split '\s+'
        docker compose -f docker-compose.dev.yml up -d --no-build --no-deps @QaBackendArr
        Write-Info "Phase 3: remaining services..."
        $QaAllArr = ($QaAll -split '\s+' | Select-Object -Unique)
        docker compose -f docker-compose.dev.yml up -d --no-build --no-deps @QaAllArr

    } else {
        $Services = switch ($Team) {
            "cyrex"          { if ($Tier -eq "1") { "$CyrexServices ollama" } else { $CyrexServices } }
            "ai"             { if ($Tier -eq "1") { "$AiServices ollama" } else { $AiServices } }
            "ml"             { $MlServices }
            "backend"        { $BackendInfraServices }
            "infrastructure" { $BackendInfraServices }
            "frontend"       { $FrontendServices }
        }
        $ServiceArray = ($Services -split '\s+' | Where-Object { $_ -ne "" } | Select-Object -Unique)
        Write-Host ""
        Write-Info "Services: $($ServiceArray -join ' ')"
        Write-Host ""
        docker compose -f docker-compose.dev.yml up -d --no-build --no-deps @ServiceArray
    }

    Write-Ok "Docker services started"
} else {
    Write-Warn "Skipping Docker startup (-SkipDocker)"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
Write-Header "Done"
Write-Host ""
Write-Host "  Team: $Team  |  Tier: $Tier  |  GPU: $Gpu  |  RAM: ${RamGB}GB" -ForegroundColor White
Write-Host ""
Write-Host "  Endpoints:"
Write-Host "    API Gateway:     http://localhost:5100"
Write-Host "    Cyrex:           http://localhost:8000"
Write-Host "    Cyrex Interface: http://localhost:5175"
Write-Host "    MLflow:          http://localhost:5500"
Write-Host "    Frontend:        http://localhost:5173"
Write-Host "    Synapse:         http://localhost:8002"
if ($Tier -eq "1") { Write-Host "    Ollama:          http://localhost:11434" }
Write-Host ""
Write-Host "  Commands:"
Write-Host "    Logs:   docker compose -f docker-compose.dev.yml logs -f <service>"
Write-Host "    Status: docker compose -f docker-compose.dev.yml ps"
Write-Host "    Stop:   docker compose -f docker-compose.dev.yml down"
Write-Host ""
