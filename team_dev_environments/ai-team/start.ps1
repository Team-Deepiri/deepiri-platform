# AI Team - Start Script
# Starts all AI services with k8s configmaps and secrets

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)

Set-Location $PROJECT_ROOT

Write-Host "🚀 Starting AI Team Environment..." -ForegroundColor Green
Write-Host "   (Using k8s configmaps and secrets from ops/k8s/)" -ForegroundColor Gray
Write-Host ""

# Use wrapper to auto-load k8s config
& .\docker-compose-k8s.ps1 -f docker-compose.ai-team.yml up -d

Write-Host ""
Write-Host "✅ AI Team Environment Started!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your services:" -ForegroundColor Yellow
Write-Host "  - Cyrex API:       http://localhost:8000"
Write-Host "  - Cyrex Interface: http://localhost:5175"
Write-Host "  - MLflow:          http://localhost:5500"
Write-Host "  - Jupyter:         http://localhost:8888"
Write-Host "  - MinIO Console:   http://localhost:9001"
Write-Host ""
Write-Host "View logs:" -ForegroundColor Gray
Write-Host "  docker compose -f docker-compose.ai-team.yml logs -f"
Write-Host ""

