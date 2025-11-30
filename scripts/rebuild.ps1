# Deepiri Clean Rebuild Script (PowerShell)
# Removes old images, rebuilds fresh, and starts services
# Usage: .\rebuild.ps1 [docker-compose-file]

param(
    [string]$ComposeFile = "docker-compose.dev.yml"
)

$env:BUILD_TIMESTAMP = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# Detect if we need to use .exe versions (Windows)
# Try docker first, fallback to docker.exe if not found
$DockerCmd = "docker"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    if (Get-Command docker.exe -ErrorAction SilentlyContinue) {
        $DockerCmd = "docker.exe"
        Write-Host "🔍 Using docker.exe" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Error: docker or docker.exe not found. Please install Docker." -ForegroundColor Red
        exit 1
    }
}

# Test if docker daemon is accessible
try {
    & $DockerCmd ps | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon not accessible"
    }
} catch {
    Write-Host "❌ Error: Cannot connect to Docker daemon. Is Docker running?" -ForegroundColor Red
    exit 1
}

# Detect docker compose command
$ComposeCmd = "docker compose"
try {
    & $DockerCmd compose version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose not available"
    }
} catch {
    # Try docker-compose.exe as fallback
    if (Get-Command docker-compose.exe -ErrorAction SilentlyContinue) {
        $ComposeCmd = "docker-compose.exe"
        Write-Host "🔍 Using docker-compose.exe" -ForegroundColor Yellow
    } elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $ComposeCmd = "docker-compose"
        Write-Host "🔍 Using docker-compose" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Warning: docker compose not available, but continuing..." -ForegroundColor Yellow
    }
}

Write-Host "🧹 Stopping containers and removing old images..." -ForegroundColor Yellow
& $ComposeCmd -f $ComposeFile down --rmi all --volumes --remove-orphans

Write-Host "🔨 Rebuilding containers (no cache)..." -ForegroundColor Yellow
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Setup .dev_venv if it doesn't exist (one level above deepiri)
$ParentDir = Split-Path -Parent $ScriptDir
$VenvPath = Join-Path $ParentDir ".dev_venv"
if (-not (Test-Path $VenvPath)) {
    Write-Host "🔧 Setting up .dev_venv for faster builds..." -ForegroundColor Cyan
    if (Test-Path "$ScriptDir\scripts\setup-dev-venv.ps1") {
        & "$ScriptDir\scripts\setup-dev-venv.ps1"
    } else {
        Write-Host "⚠️  Warning: setup-dev-venv.ps1 not found, skipping venv setup" -ForegroundColor Yellow
    }
}

# Note: Docker builds use prebuilt images and downloaded packages
# No need to export from host venv - builds are self-contained

# Build cyrex and jupyter with auto GPU detection (uses prebuilt, fastest)
Write-Host "🤖 Building cyrex and jupyter with auto GPU detection..." -ForegroundColor Cyan
if (Test-Path "$ScriptDir\scripts\build-cyrex-auto.ps1") {
    & "$ScriptDir\scripts\build-cyrex-auto.ps1" all
} else {
    Write-Host "⚠️  Warning: build-cyrex-auto.ps1 not found, falling back to standard build" -ForegroundColor Yellow
    & $ComposeCmd -f $ComposeFile build --no-cache --pull cyrex jupyter
}

Write-Host ""
Write-Host "🔨 Building other services..." -ForegroundColor Yellow
# Build other services (excluding cyrex and jupyter which were already built)
& $ComposeCmd -f $ComposeFile build --no-cache --pull

Write-Host "🚀 Starting services..." -ForegroundColor Yellow
& $ComposeCmd -f $ComposeFile up -d

Write-Host "✅ Rebuild complete!" -ForegroundColor Green
Write-Host ""
Write-Host "View logs: $ComposeCmd -f $ComposeFile logs -f" -ForegroundColor Cyan
Write-Host "Check status: $ComposeCmd -f $ComposeFile ps" -ForegroundColor Cyan

