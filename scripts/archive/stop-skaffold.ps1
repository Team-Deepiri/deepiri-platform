# Stop Skaffold and cleanup Kubernetes resources (PowerShell)
# This script stops Skaffold dev mode and cleans up resources

Write-Host "🛑 Stopping Skaffold and cleaning up..." -ForegroundColor Yellow

# Check if skaffold is running
$skaffoldProcess = Get-Process -Name skaffold -ErrorAction SilentlyContinue
if ($skaffoldProcess) {
    Write-Host "⚠️  Skaffold is running. Please stop it first (Ctrl+C in the Skaffold terminal)." -ForegroundColor Yellow
    $continue = Read-Host "Continue with cleanup anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Delete resources using Skaffold
if (Get-Command skaffold -ErrorAction SilentlyContinue) {
    Write-Host "🗑️  Deleting resources with Skaffold..." -ForegroundColor Cyan
    skaffold delete 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Skaffold delete failed (may already be cleaned up)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Skaffold not found, using kubectl directly..." -ForegroundColor Yellow
}

# Cleanup using kubectl
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    Write-Host "🧹 Cleaning up Kubernetes resources..." -ForegroundColor Cyan
    
    # Delete deployments
    kubectl delete deployment deepiri-core-api,deepiri-cyrex,redis,localai 2>&1 | Out-Null
    
    # Delete services
    kubectl delete service backend-service,cyrex-service,redis-service,localai-service 2>&1 | Out-Null
    
    # Delete ConfigMaps and Secrets
    kubectl delete configmap deepiri-config 2>&1 | Out-Null
    kubectl delete secret deepiri-secrets 2>&1 | Out-Null
    
    Write-Host "✅ Kubernetes resources cleaned up" -ForegroundColor Green
} else {
    Write-Host "⚠️  kubectl not found. Skipping Kubernetes cleanup." -ForegroundColor Yellow
}

# Optionally stop Minikube
$stopMinikube = Read-Host "Stop Minikube cluster? (y/N)"
if ($stopMinikube -eq "y" -or $stopMinikube -eq "Y") {
    if (Get-Command minikube -ErrorAction SilentlyContinue) {
        Write-Host "🛑 Stopping Minikube..." -ForegroundColor Cyan
        minikube stop
    } else {
        Write-Host "⚠️  Minikube not found" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 To completely remove Minikube cluster:" -ForegroundColor Cyan
Write-Host "   minikube delete"

