# Backend Team - Start Script
# Starts all backend services with k8s configmaps and secrets

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)

Set-Location $PROJECT_ROOT

Write-Host "🚀 Starting Backend Team Environment..." -ForegroundColor Green
Write-Host "   (Using k8s configmaps and secrets from ops/k8s/)" -ForegroundColor Gray
Write-Host ""

# Backend team services
$SERVICES = @(
  "postgres", "redis", "influxdb",
  "api-gateway", "auth-service", "task-orchestrator",
  "engagement-service", "platform-analytics-service",
  "notification-service", "external-bridge-service",
  "challenge-service", "realtime-gateway"
)

Write-Host "   (Using docker-compose.dev.yml with service selection)" -ForegroundColor Gray
Write-Host "   Services: $($SERVICES -join ', ')" -ForegroundColor Gray
Write-Host ""

# Use wrapper to auto-load k8s config, then start selected services
& .\docker-compose-k8s.ps1 -f docker-compose.dev.yml up -d $SERVICES

Write-Host ""
Write-Host "✅ Backend Team Environment Started!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your services:" -ForegroundColor Yellow
Write-Host "  - Frontend:        http://localhost:5173"
Write-Host "  - API Gateway:     http://localhost:5100"
Write-Host "  - Auth Service:    http://localhost:5001"
Write-Host "  - pgAdmin: http://localhost:5050"
Write-Host ""
Write-Host "View logs:" -ForegroundColor Gray
Write-Host "  docker compose -f docker-compose.dev.yml logs -f $($SERVICES -join ' ')"
Write-Host ""

