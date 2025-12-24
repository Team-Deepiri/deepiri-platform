# Platform Engineers - Start Script
# Starts full stack (all services) with k8s configmaps and secrets

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)

Set-Location $PROJECT_ROOT

Write-Host "🚀 Starting Platform Engineers Environment (Full Stack)..." -ForegroundColor Green
Write-Host "   (Using k8s configmaps and secrets from ops/k8s/)" -ForegroundColor Gray
Write-Host ""

Write-Host "   (Using docker-compose.dev.yml - all services)" -ForegroundColor Gray
Write-Host ""

# Use wrapper to auto-load k8s config, then start all services
& .\docker-compose-k8s.ps1 -f docker-compose.dev.yml up -d

Write-Host ""
Write-Host "✅ Platform Engineers Environment Started!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your services:" -ForegroundColor Yellow
Write-Host "  - Frontend:        http://localhost:5173"
Write-Host "  - API Gateway:     http://localhost:5100"
Write-Host "  - Cyrex API:       http://localhost:8000"
Write-Host "  - Cyrex Interface: http://localhost:5175"
Write-Host "  - MLflow:          http://localhost:5500"
Write-Host "  - Jupyter:         http://localhost:8888"
Write-Host "  - pgAdmin: http://localhost:5050"
Write-Host "  - MinIO Console:   http://localhost:9001"
Write-Host ""
Write-Host "View logs:" -ForegroundColor Gray
Write-Host "  docker compose -f docker-compose.dev.yml logs -f"
Write-Host ""

