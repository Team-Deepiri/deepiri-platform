# Build script for cyrex service with automatic GPU detection and CPU fallback (PowerShell)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$CyrexDir = Join-Path $ProjectRoot "diri-cyrex"

Write-Host "🔍 Detecting GPU capabilities..." -ForegroundColor Cyan

# Detect GPU and get base image
if (Test-Path "$CyrexDir\detect_gpu.ps1") {
    $BaseImage = & "$CyrexDir\detect_gpu.ps1"
} else {
    # Fallback: check if nvidia-smi exists
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        Write-Host "NVIDIA GPU detected, using CUDA image" -ForegroundColor Green
        $BaseImage = "pytorch/pytorch:2.0.0-cuda12.1-cudnn8-runtime"
    } else {
        Write-Host "No NVIDIA GPU detected, using CPU image" -ForegroundColor Yellow
        $BaseImage = "pytorch/pytorch:2.0.0-cpu"
    }
}

Write-Host "📦 Using base image: $BaseImage" -ForegroundColor Green
Write-Host "🔨 Building cyrex service..." -ForegroundColor Cyan

# Set BASE_IMAGE environment variable for docker-compose
$env:BASE_IMAGE = $BaseImage

# Build with detected base image
Set-Location $ProjectRoot
docker compose -f docker-compose.dev.yml build --build-arg BASE_IMAGE="$BaseImage" cyrex jupyter

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build complete!" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

