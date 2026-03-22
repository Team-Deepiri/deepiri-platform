# Quick launcher script - Run this directly from PowerShell
# This script sets execution policy and runs the cleanup script

Write-Host "Setting execution policy for this session..." -ForegroundColor Yellow
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Running cleanup script..." -ForegroundColor Green
Write-Host ""

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cleanupScript = Join-Path $scriptDir "cleanup-and-compact.ps1"

if (Test-Path $cleanupScript) {
    & $cleanupScript
} else {
    Write-Host "[ERROR] Cleanup script not found at: $cleanupScript" -ForegroundColor Red
    exit 1
}

