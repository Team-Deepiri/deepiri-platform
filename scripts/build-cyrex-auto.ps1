# Auto-build script that detects GPU and builds accordingly (PowerShell)
# Usage: .\build-cyrex-auto.ps1 [cyrex|jupyter|all]

param(
    [string]$Service = "all"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$CyrexDir = Join-Path $ProjectRoot "diri-cyrex"

# Detect if we need to use .exe versions (Windows)
# Try docker first, fallback to docker.exe if not found
$DockerCmd = "docker"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    if (Get-Command docker.exe -ErrorAction SilentlyContinue) {
        $DockerCmd = "docker.exe"
        Write-Host "🔍 Using docker.exe" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Error: docker or docker.exe not found. Please install Docker." -ForegroundColor Red
        exit 1
    }
}

# Test if docker daemon is accessible
try {
    & $DockerCmd ps | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon not accessible"
    }
} catch {
    Write-Host "❌ Error: Cannot connect to Docker daemon. Is Docker running?" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 Auto-detecting GPU capabilities..." -ForegroundColor Cyan

# Detect GPU and get base image
if (Test-Path "$CyrexDir\detect_gpu.ps1") {
    $BaseImage = & "$CyrexDir\detect_gpu.ps1"
} else {
    # Fallback detection
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        try {
            $gpuInfo = nvidia-smi --query-gpu=memory.total --format=csv,noheader | Select-Object -First 1
            if ($gpuInfo) {
                $memoryValue = [regex]::Match($gpuInfo, '(\d+)').Groups[1].Value
                $memoryGB = [math]::Round([int]$memoryValue / 1024, 1)
                if ($memoryGB -ge 4) {
                    Write-Host "GPU detected (${memoryGB}GB), using CUDA image" -ForegroundColor Green
                    $BaseImage = "pytorch/pytorch:2.0.0-cuda12.1-cudnn8-runtime"
                } else {
                    Write-Host "GPU memory (${memoryGB}GB) below minimum, using CPU image" -ForegroundColor Yellow
                    $BaseImage = "python:3.11-slim"
                }
            } else {
                $BaseImage = "python:3.11-slim"
            }
        } catch {
            Write-Host "Error detecting GPU, using CPU image" -ForegroundColor Yellow
            $BaseImage = "python:3.11-slim"
        }
    } else {
        Write-Host "No NVIDIA GPU detected, using CPU image" -ForegroundColor Yellow
        $BaseImage = "python:3.11-slim"
    }
}

Write-Host "📦 Using base image: $BaseImage" -ForegroundColor Green
Write-Host "🔨 Building service(s): $Service" -ForegroundColor Cyan

# Set environment variables for build
$env:BASE_IMAGE = $BaseImage
$env:BUILD_TYPE = "prebuilt"  # Use prebuilt by default (fastest)

# Build selected service(s) - use final-prebuilt target (default, fastest)
# Note: docker compose doesn't support --target, so we use docker build directly
Set-Location $ProjectRoot

# PowerShell already uses Windows paths, so no conversion needed
$DockerfilePath = Join-Path $CyrexDir "Dockerfile"
$DockerfileJupyterPath = Join-Path $CyrexDir "Dockerfile.jupyter"

switch ($Service.ToLower()) {
    "cyrex" {
        & $DockerCmd build `
            --target final-prebuilt `
            --build-arg BASE_IMAGE="$BaseImage" `
            --build-arg BUILD_TYPE="prebuilt" `
            --build-arg PYTORCH_VERSION="2.0.0" `
            --build-arg CUDA_VERSION="12.1" `
            --build-arg PYTHON_VERSION="3.11" `
            -f "$DockerfilePath" `
            -t deepiri-dev-cyrex:latest `
            "$CyrexDir"
    }
    "jupyter" {
        & $DockerCmd build `
            --target final-prebuilt `
            --build-arg BASE_IMAGE="$BaseImage" `
            --build-arg BUILD_TYPE="prebuilt" `
            --build-arg PYTORCH_VERSION="2.0.0" `
            --build-arg CUDA_VERSION="12.1" `
            --build-arg PYTHON_VERSION="3.11" `
            -f "$DockerfileJupyterPath" `
            -t deepiri-dev-jupyter:latest `
            "$CyrexDir"
    }
    default {
        & $DockerCmd build `
            --target final-prebuilt `
            --build-arg BASE_IMAGE="$BaseImage" `
            --build-arg BUILD_TYPE="prebuilt" `
            --build-arg PYTORCH_VERSION="2.0.0" `
            --build-arg CUDA_VERSION="12.1" `
            --build-arg PYTHON_VERSION="3.11" `
            -f "$DockerfilePath" `
            -t deepiri-dev-cyrex:latest `
            "$CyrexDir"
        & $DockerCmd build `
            --target final-prebuilt `
            --build-arg BASE_IMAGE="$BaseImage" `
            --build-arg BUILD_TYPE="prebuilt" `
            --build-arg PYTORCH_VERSION="2.0.0" `
            --build-arg CUDA_VERSION="12.1" `
            --build-arg PYTHON_VERSION="3.11" `
            -f "$DockerfileJupyterPath" `
            -t deepiri-dev-jupyter:latest `
            "$CyrexDir"
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build complete!" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

