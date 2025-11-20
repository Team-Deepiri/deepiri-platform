# Start Deepiri production deployment with Skaffold (PowerShell)
# This script deploys to cloud/production Kubernetes clusters

param(
    [string]$Profile = "prod",
    [string]$Namespace = "default",
    [switch]$PortForward = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "Usage: .\start-skaffold-prod.ps1 [OPTIONS]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Profile PROFILE     Skaffold profile to use (prod, staging, gpu) [default: prod]"
    Write-Host "  -Namespace NAMESPACE Kubernetes namespace [default: default]"
    Write-Host "  -PortForward         Enable port forwarding"
    Write-Host "  -Help                Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\start-skaffold-prod.ps1                                    # Deploy to production"
    Write-Host "  .\start-skaffold-prod.ps1 -Profile staging                  # Deploy to staging"
    Write-Host "  .\start-skaffold-prod.ps1 -Profile prod -PortForward        # Deploy with port forwarding"
    exit 0
}

Write-Host "🚀 Starting Deepiri Production Deployment with Skaffold..." -ForegroundColor Cyan

# Check if skaffold is installed
if (-not (Get-Command skaffold -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Skaffold is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if we're in the right directory
if (-not (Test-Path "skaffold-cloud.yaml") -and -not (Test-Path "skaffold.yaml")) {
    Write-Host "❌ skaffold-cloud.yaml or skaffold.yaml not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# Check if k8s manifests exist
if (-not (Test-Path "ops/k8s")) {
    Write-Host "❌ Kubernetes manifests not found in ops/k8s/" -ForegroundColor Red
    exit 1
}

# Check kubectl connection
Write-Host "🔧 Checking Kubernetes connection..." -ForegroundColor Cyan
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    # Check if KUBECONFIG is set (for CI/CD) or if we're in-cluster
    if ($env:KUBECONFIG) {
        Write-Host "✅ Using kubeconfig: $($env:KUBECONFIG)" -ForegroundColor Green
        if (-not (Test-Path $env:KUBECONFIG)) {
            Write-Host "⚠️  Warning: KUBECONFIG file not found at $($env:KUBECONFIG)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️  KUBECONFIG not set - will try in-cluster config (if running in a pod)" -ForegroundColor Yellow
        Write-Host "   For local/CI deployments, set KUBECONFIG environment variable" -ForegroundColor Yellow
    }
    
    # Try to get cluster info
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -eq 0) {
        $currentContext = kubectl config current-context 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Connected to Kubernetes cluster: $currentContext" -ForegroundColor Green
        } else {
            Write-Host "✅ Connected to Kubernetes cluster (in-cluster)" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠️  Warning: Cannot connect to Kubernetes cluster" -ForegroundColor Yellow
        Write-Host "   Make sure KUBECONFIG is set or you're running in a Kubernetes pod" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Warning: kubectl is not installed. Skaffold may have issues connecting to Kubernetes." -ForegroundColor Yellow
}

# Use skaffold-cloud.yaml for production deployments
$configFile = "skaffold-cloud.yaml"
if (-not (Test-Path $configFile)) {
    Write-Host "⚠️  Warning: $configFile not found, falling back to skaffold.yaml" -ForegroundColor Yellow
    $configFile = "skaffold.yaml"
}

Write-Host ""
Write-Host "✅ Environment ready. Starting Skaffold (PRODUCTION mode)..." -ForegroundColor Green
Write-Host ""
Write-Host "📋 Deployment Configuration:" -ForegroundColor Cyan
Write-Host "   - Config file: $configFile"
Write-Host "   - Profile: $Profile"
Write-Host "   - Namespace: $Namespace"
Write-Host "   - Port forwarding: $PortForward"
Write-Host ""
Write-Host "📋 Skaffold will:" -ForegroundColor Cyan
Write-Host "   - Build Docker images"
Write-Host "   - Push images to container registry"
Write-Host "   - Deploy to Kubernetes cluster"
if ($PortForward) {
    Write-Host "   - Port-forward services"
}
Write-Host ""

# Confirm before proceeding (unless in CI/CD)
if (-not $env:CI -and -not $env:SKIP_CONFIRM) {
    $confirmation = Read-Host "Continue with production deployment? (y/N)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "❌ Deployment cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Build Skaffold command
$skaffoldArgs = @(
    "run",
    "-f",
    "$configFile",
    "--profile=$Profile"
)

if ($PortForward) {
    $skaffoldArgs += "--port-forward"
}

# Execute Skaffold
Write-Host "🚀 Starting deployment..." -ForegroundColor Cyan
& skaffold $skaffoldArgs

Write-Host ""
Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Useful commands:" -ForegroundColor Cyan
Write-Host "   - View pods: kubectl get pods -n $Namespace"
Write-Host "   - View services: kubectl get services -n $Namespace"
Write-Host "   - View logs: kubectl logs -f deployment/<deployment-name> -n $Namespace"
Write-Host "   - Delete deployment: skaffold delete -f $configFile --profile=$Profile"
Write-Host ""

