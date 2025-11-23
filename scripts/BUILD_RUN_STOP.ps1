# Simple 5-command workflow for Deepiri development
# Usage: .\BUILD_RUN_STOP.ps1 [build|run|logs|stop|rebuild]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('build','run','logs','stop','rebuild','status')]
    [string]$Command
)

$ErrorActionPreference = "Stop"

# Set Minikube Docker environment
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

switch ($Command) {
    'build' {
        Write-Host "🏗️  Building all services..." -ForegroundColor Cyan
        Set-Location deepiri
        skaffold build -f skaffold-local.yaml -p dev-compose
        Write-Host "✅ Build complete! Images tagged with :latest (overwrites old ones)" -ForegroundColor Green
    }
    
    'run' {
        Write-Host "🚀 Starting all services..." -ForegroundColor Cyan
        Set-Location deepiri
        docker-compose -f docker-compose.dev.yml up -d
        Write-Host "✅ All services running!" -ForegroundColor Green
        Write-Host "💡 Use './BUILD_RUN_STOP.ps1 logs' to view logs" -ForegroundColor Yellow
    }
    
    'logs' {
        Write-Host "📋 Viewing logs (Ctrl+C to exit)..." -ForegroundColor Cyan
        Set-Location deepiri
        docker-compose -f docker-compose.dev.yml logs -f
    }
    
    'stop' {
        Write-Host "🛑 Stopping all services..." -ForegroundColor Cyan
        Set-Location deepiri
        docker-compose -f docker-compose.dev.yml down
        Write-Host "✅ All services stopped!" -ForegroundColor Green
    }
    
    'rebuild' {
        Write-Host "🔄 Rebuilding (this OVERWRITES existing images, no duplicates)..." -ForegroundColor Cyan
        Set-Location deepiri
        
        # Stop services
        Write-Host "  1/3 Stopping services..." -ForegroundColor Yellow
        docker-compose -f docker-compose.dev.yml down
        
        # Rebuild (will overwrite existing :latest tags)
        Write-Host "  2/3 Rebuilding images..." -ForegroundColor Yellow
        skaffold build -f skaffold-local.yaml -p dev-compose
        
        # Start services
        Write-Host "  3/3 Starting services..." -ForegroundColor Yellow
        docker-compose -f docker-compose.dev.yml up -d
        
        Write-Host "✅ Rebuild complete! Changes are now live." -ForegroundColor Green
        Write-Host "💾 Storage used: Same as before (images overwritten, not duplicated)" -ForegroundColor Cyan
    }
    
    'status' {
        Write-Host "📊 Docker Images:" -ForegroundColor Cyan
        docker images | Select-String "deepiri-dev"
        Write-Host "`n📦 Running Containers:" -ForegroundColor Cyan
        Set-Location deepiri
        docker-compose -f docker-compose.dev.yml ps
    }
}

