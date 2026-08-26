# Quick start script for Docker Compose (fastest way to run pre-built containers)

Write-Host "Starting Deepiri with Docker Compose (fast mode)..." -ForegroundColor Cyan

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Resolve-ComposeFile {
    param([string]$Root)
    $cloud = Join-Path $Root "docker-compose.yml"
    $dev = Join-Path $Root "docker-compose.dev.yml"
    if ((Test-Path $cloud) -and (Select-String -Path $cloud -Pattern 'postgres-platform' -Quiet)) {
        return @{ File = $cloud; Role = 'cloud-portal' }
    }
    if ((Test-Path $dev) -and (Select-String -Path $dev -Pattern '^  cyrex:' -Quiet)) {
        return @{ File = $dev; Role = 'control-plane' }
    }
    Write-Host "Cannot detect compose file. Cloud portal -> deepiri-platform; dev stack -> deepiri-control-plane" -ForegroundColor Red
    exit 1
}

$resolved = Resolve-ComposeFile -Root $RepoRoot
$composeFile = $resolved.File
$repoRole = $resolved.Role

if (-not (Test-Path $composeFile)) {
    Write-Host "Compose file not found: $composeFile" -ForegroundColor Red
    exit 1
}

$composeCmd = "docker compose"
if (-not (docker compose version 2>$null)) {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $composeCmd = "docker-compose"
    } else {
        Write-Host "Docker Compose is not installed." -ForegroundColor Red
        exit 1
    }
}

if (Get-Command minikube -ErrorAction SilentlyContinue) {
    $minikubeStatus = minikube status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Minikube is running - using Minikube Docker daemon" -ForegroundColor Cyan
        Invoke-Expression (minikube docker-env)
    }
}

try {
    docker ps | Out-Null
} catch {
    Write-Host "Docker is not running." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting services ($repoRole)..." -ForegroundColor Cyan
Write-Host ""

Push-Location $RepoRoot
try {
    & docker compose -f $composeFile up -d
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Services started!" -ForegroundColor Green
        Write-Host ""
        if ($repoRole -eq 'cloud-portal') {
            Write-Host "Portal (nginx): http://localhost" -ForegroundColor Cyan
        } else {
            Write-Host "Backend API: http://localhost:5000" -ForegroundColor Cyan
            Write-Host "Cyrex AI:    http://localhost:8000" -ForegroundColor Cyan
        }
    } else {
        exit 1
    }
} finally {
    Pop-Location
}
