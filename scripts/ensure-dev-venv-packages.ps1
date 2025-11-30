# Ensure .dev_venv_packages directory exists (even if empty) to prevent Docker COPY failures
# This script should be run before building if .dev_venv_packages doesn't exist

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$PackagesDir = Join-Path $ProjectRoot "diri-cyrex\.dev_venv_packages"

if (-not (Test-Path $PackagesDir)) {
    Write-Host "Creating empty .dev_venv_packages directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $PackagesDir | Out-Null
    New-Item -ItemType File -Path (Join-Path $PackagesDir ".keep") -Force | Out-Null
    Write-Host "✓ Created empty .dev_venv_packages directory" -ForegroundColor Green
    Write-Host "  Run: .\scripts\export-venv-packages.ps1 to populate it" -ForegroundColor Cyan
} else {
    Write-Host "✓ .dev_venv_packages already exists" -ForegroundColor Green
}

