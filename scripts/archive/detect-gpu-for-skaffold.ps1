# GPU Detection for Skaffold (PowerShell)
# Detects GPU and runs skaffold with appropriate profile

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CyrexDir = Join-Path $ScriptDir ".." "diri-cyrex"
$ProjectRoot = Join-Path $ScriptDir ".."

Write-Host "🔍 Detecting GPU and configuring environment..." -ForegroundColor Cyan

# Check if minikube is running
$minikubeStatus = minikube status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Minikube is not running. Starting Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker --cpus=4 --memory=8192
}

# Configure Docker to use Minikube's Docker daemon
Write-Host "🔧 Configuring Docker environment for Minikube..." -ForegroundColor Cyan
$dockerEnv = minikube docker-env
if ($dockerEnv) {
    $dockerEnv | ForEach-Object {
        if ($_ -match '^export\s+(\w+)="?([^"]+)"?$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            [Environment]::SetEnvironmentVariable($varName, $varValue, "Process")
        }
    }
}

# Verify Docker is accessible
$dockerCheck = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker is not accessible after switching to Minikube's Docker daemon." -ForegroundColor Red
    Write-Host "   Try running: minikube start" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Docker is accessible (using Minikube's Docker daemon)" -ForegroundColor Green

# Run the GPU detection script
$DetectGpuScript = Join-Path $CyrexDir "detect_gpu.ps1"

if (Test-Path $DetectGpuScript) {
    $BaseImage = & $DetectGpuScript
    
    # Determine profile based on BASE_IMAGE
    if ($BaseImage -like "*pytorch*") {
        $Profile = "gpu"
        Write-Host "✅ GPU detected! Using GPU profile with: $BaseImage" -ForegroundColor Green
    } else {
        $Profile = "cpu"
        Write-Host "ℹ️  No GPU or GPU below requirements. Using CPU profile with: $BaseImage" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Running: skaffold build --profile=$Profile" -ForegroundColor Cyan
    Write-Host ""
    
    # Change to project root and run skaffold
    Set-Location $ProjectRoot
    skaffold build --profile=$Profile $args
} else {
    Write-Host "Error: detect_gpu.ps1 not found at $DetectGpuScript" -ForegroundColor Red
    exit 1
}

