# Setup script for Minikube on WSL2 (PowerShell version)
# This script configures Minikube with Docker driver for local development

Write-Host "🚀 Setting up Minikube for Deepiri on WSL2..." -ForegroundColor Cyan

# Check if minikube is installed
if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Minikube is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "   Install via: choco install minikube" -ForegroundColor Yellow
    Write-Host "   Or download from: https://minikube.sigs.k8s.io/docs/start/" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check if kubectl is installed
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl is not installed. Installing..." -ForegroundColor Yellow
    # For Windows, you can use chocolatey or download directly
    Write-Host "   Install via: choco install kubernetes-cli" -ForegroundColor Yellow
    Write-Host "   Or download from: https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Yellow
    exit 1
}

# Check if skaffold is installed
if (-not (Get-Command skaffold -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️  Skaffold is not installed. Installing..." -ForegroundColor Yellow
    Write-Host "   Install via: choco install skaffold" -ForegroundColor Yellow
    Write-Host "   Or download from: https://skaffold.dev/docs/install/" -ForegroundColor Yellow
    exit 1
}

# Stop existing minikube if running
$minikubeStatus = minikube status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "🛑 Stopping existing Minikube cluster..." -ForegroundColor Yellow
    minikube stop
}

# Start Minikube with Docker driver
Write-Host "🏗️  Starting Minikube cluster with Docker driver..." -ForegroundColor Cyan
minikube start `
    --driver=docker `
    --cpus=4 `
    --memory=8192 `
    --disk-size=20g `
    --addons=ingress `
    --addons=dashboard

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start Minikube. Check the error messages above." -ForegroundColor Red
    exit 1
}

# Configure Docker to use Minikube's Docker daemon
Write-Host "🔧 Configuring Docker environment for Minikube..." -ForegroundColor Cyan
$dockerEnv = minikube docker-env
Invoke-Expression $dockerEnv

# Verify setup
Write-Host "✅ Verifying setup..." -ForegroundColor Cyan
minikube status
kubectl cluster-info

# Show helpful commands
Write-Host ""
Write-Host "✅ Minikube setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Useful commands:" -ForegroundColor Cyan
Write-Host "   minikube dashboard          # Open Kubernetes dashboard"
Write-Host "   minikube service list       # List all services"
Write-Host "   minikube tunnel            # Expose LoadBalancer services"
Write-Host "   minikube docker-env        # Get Docker environment commands"
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Make sure you're in the Minikube Docker environment:"
Write-Host "      `$env:DOCKER_HOST = (minikube docker-env | Select-String 'DOCKER_HOST').ToString().Split('=')[1].Trim('`"')"
Write-Host "   2. Run Skaffold:"
Write-Host "      skaffold dev --port-forward"
Write-Host ""

