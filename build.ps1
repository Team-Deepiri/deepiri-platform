# Smart build script for Windows - automatically cleans up dangling images
# Usage: .\build.ps1 [service-name] [--no-cache]

param(
    [string]$Service = "",
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Enable BuildKit
$env:DOCKER_BUILDKIT = "1"
$env:COMPOSE_DOCKER_CLI_BUILD = "1"

$NoCacheFlag = if ($NoCache) { "--no-cache" } else { "" }

# Build
Write-Host "Building..." -ForegroundColor Green
if ([string]::IsNullOrEmpty($Service)) {
    wsl docker compose -f docker-compose.dev.yml build $NoCacheFlag
} else {
    wsl docker compose -f docker-compose.dev.yml build $NoCacheFlag $Service
}

# Auto-cleanup dangling images
Write-Host "Cleaning up dangling images..." -ForegroundColor Green
$danglingImages = wsl docker images -f "dangling=true" -q
if ($danglingImages) {
    $danglingImages -split "`n" | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
        wsl docker rmi -f $_.Trim() 2>$null | Out-Null
    }
}

Write-Host "✓ Build complete!" -ForegroundColor Green
wsl docker system df

