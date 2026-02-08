# Start Deepiri development environment with Skaffold (PowerShell)
# This script ensures proper environment setup before running Skaffold

Write-Host "🚀 Starting Deepiri with Skaffold..." -ForegroundColor Cyan

# Check if minikube is running
$minikubeStatus = minikube status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Minikube is not running. Starting Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker --cpus=4 --memory=8192
}

# Configure Docker to use Minikube's Docker daemon
Write-Host "🔧 Configuring Docker environment for Minikube..." -ForegroundColor Cyan
$dockerEnv = minikube docker-env
Invoke-Expression $dockerEnv

# Verify Docker is accessible
try {
    docker ps | Out-Null
} catch {
    Write-Host "❌ Docker is not accessible. Please check your Docker setup." -ForegroundColor Red
    exit 1
}

# Check if skaffold is installed
if (-not (Get-Command skaffold -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Skaffold is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if we're in the right directory
if (-not (Test-Path "skaffold-local.yaml") -and -not (Test-Path "skaffold.yaml")) {
    Write-Host "❌ skaffold-local.yaml or skaffold.yaml not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# Check if k8s manifests exist
if (-not (Test-Path "ops/k8s")) {
    Write-Host "❌ Kubernetes manifests not found in ops/k8s/" -ForegroundColor Red
    exit 1
}

# Configure kubectl to use Minikube context
Write-Host "🔧 Configuring kubectl for Minikube..." -ForegroundColor Cyan
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    try {
        # Set kubectl context to minikube
        kubectl config use-context minikube 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Warning: Could not set kubectl context to minikube automatically" -ForegroundColor Yellow
            Write-Host "   Trying to get kubeconfig from minikube..." -ForegroundColor Yellow
            minikube update-context 2>&1 | Out-Null
        }
        
        # Verify kubectl can connect
        $clusterInfo = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Warning: kubectl cannot connect to cluster. Trying to fix..." -ForegroundColor Yellow
            minikube update-context 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $clusterInfo = kubectl cluster-info 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ kubectl cannot connect to Minikube cluster." -ForegroundColor Red
                Write-Host "   Try running: minikube start" -ForegroundColor Yellow
                exit 1
            }
        }
        Write-Host "✅ kubectl is configured and can connect to Minikube" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Warning: Error configuring kubectl: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Warning: kubectl is not installed. Skaffold may have issues connecting to Kubernetes." -ForegroundColor Yellow
}

# Unset any in-cluster config environment variables that might interfere
Remove-Item Env:\KUBERNETES_SERVICE_HOST -ErrorAction SilentlyContinue
Remove-Item Env:\KUBERNETES_SERVICE_PORT -ErrorAction SilentlyContinue

# Ensure KUBECONFIG is set (Skaffold will use this instead of in-cluster config)
if (-not $env:KUBECONFIG) {
    $env:KUBECONFIG = "$env:USERPROFILE\.kube\config"
}

# Use skaffold-local.yaml for local development
$configFile = "skaffold-local.yaml"
if (-not (Test-Path $configFile)) {
    Write-Host "⚠️  Warning: $configFile not found, falling back to skaffold.yaml" -ForegroundColor Yellow
    $configFile = "skaffold.yaml"
}

Write-Host "✅ Environment ready. Starting Skaffold (DEV mode)..." -ForegroundColor Green
Write-Host ""
Write-Host "📋 Skaffold will:" -ForegroundColor Cyan
Write-Host "   - Use config: $configFile"
Write-Host "   - Build Docker images using Minikube's Docker daemon"
Write-Host "   - Deploy to Kubernetes"
Write-Host "   - Auto-sync files for faster development"
Write-Host "   - Port-forward services automatically"
Write-Host "   - Stream logs"
Write-Host ""
Write-Host "Press Ctrl+C to stop and cleanup..." -ForegroundColor Yellow
Write-Host ""

# Run Skaffold in dev mode
skaffold dev `
    -f "$configFile" `
    --port-forward `
    --trigger=notify `
    --watch-poll=1000 `
    --default-repo=localhost:5000

