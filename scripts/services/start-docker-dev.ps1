# Quick start script for Docker Compose (fastest way to run pre-built containers)

Write-Host "🚀 Starting Deepiri with Docker Compose (fast mode)..." -ForegroundColor Cyan

# Check if docker-compose is available
$composeCmd = $null
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerCompose = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $composeCmd = "docker compose"
    } else {
        if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
            $composeCmd = "docker-compose"
        }
    }
}

if (-not $composeCmd) {
    Write-Host "❌ Docker Compose is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

$composeFile = "docker-compose.dev.yml"

# Check if compose file exists
if (-not (Test-Path $composeFile)) {
    Write-Host "❌ $composeFile not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# CRITICAL: Check if Minikube is running and use its Docker daemon
if (Get-Command minikube -ErrorAction SilentlyContinue) {
    $minikubeStatus = minikube status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "📋 Minikube is running - using Minikube's Docker daemon (where Skaffold builds images)" -ForegroundColor Cyan
        $dockerEnv = minikube docker-env
        Invoke-Expression $dockerEnv
        Write-Host "✅ Docker is now pointing to Minikube's Docker daemon" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Minikube is not running - using host Docker daemon" -ForegroundColor Yellow
    }
}

# Check if Docker is running
try {
    docker ps | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 Starting services (using existing images - fast!)..." -ForegroundColor Cyan
Write-Host "   This will NOT rebuild images - uses pre-built containers" -ForegroundColor Yellow
Write-Host ""

# Start services
$args = @("-f", $composeFile, "up", "-d")
& docker compose $args

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Services started!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Useful commands:" -ForegroundColor Cyan
    Write-Host "   View logs:        $composeCmd -f $composeFile logs -f"
    Write-Host "   View status:      $composeCmd -f $composeFile ps"
    Write-Host "   Stop services:    $composeCmd -f $composeFile down"
    Write-Host "   Restart service:  $composeCmd -f $composeFile restart <service-name>"
    Write-Host ""
    Write-Host "🌐 Services available:" -ForegroundColor Cyan
    Write-Host "   Backend API:      http://localhost:5000"
    Write-Host "   Cyrex AI:         http://localhost:8000"
    Write-Host "   MongoDB:          localhost:27017"
    Write-Host "   Redis:            localhost:6379"
    Write-Host "   Mongo Express:    http://localhost:8081"
    Write-Host ""
} else {
    Write-Host "❌ Failed to start services" -ForegroundColor Red
    exit 1
}

