# Export packages from .dev_venv to a directory that can be used in Docker builds (PowerShell)
# This allows Docker builds to use pre-installed packages from the host venv

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ParentDir = Split-Path -Parent $ProjectRoot
$VenvPath = Join-Path $ParentDir ".dev_venv"
$ExportDir = Join-Path $ProjectRoot "diri-cyrex\.dev_venv_packages"

Write-Host "📦 Exporting packages from .dev_venv..." -ForegroundColor Cyan

if (-not (Test-Path $VenvPath)) {
    Write-Host "⚠️  Warning: .dev_venv not found at $VenvPath" -ForegroundColor Yellow
    Write-Host "💡 Run .\scripts\setup-dev-venv.ps1 to create it" -ForegroundColor Yellow
    exit 0  # Not an error, just skip
}

# Find Python version in venv
$PythonDirs = Get-ChildItem -Path "$VenvPath\lib" -Directory -Filter "python*" | Select-Object -First 1
if (-not $PythonDirs) {
    Write-Host "⚠️  Warning: Python directory not found in venv" -ForegroundColor Yellow
    exit 0
}

$PythonVersion = $PythonDirs.Name
$SitePackages = Join-Path $VenvPath "lib\$PythonVersion\site-packages"

if (-not (Test-Path $SitePackages)) {
    Write-Host "⚠️  Warning: site-packages not found at $SitePackages" -ForegroundColor Yellow
    exit 0
}

# Create export directory
New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null

# Copy wheel files and package directories
Write-Host "📋 Copying packages..." -ForegroundColor Cyan
Get-ChildItem -Path $SitePackages -Recurse -Include "*.whl", "*.egg" | Copy-Item -Destination $ExportDir -Force
Get-ChildItem -Path $SitePackages -Directory | Copy-Item -Destination $ExportDir -Recurse -Force

# Also create a pip download of key packages
Write-Host "⬇️  Downloading key packages as wheels..." -ForegroundColor Cyan
$PipPath = Join-Path $VenvPath "Scripts\pip.exe"
if (Test-Path $PipPath) {
    & $PipPath download --no-deps --dest $ExportDir `
        transformers datasets accelerate sentence-transformers `
        2>$null
}

Write-Host "✅ Packages exported to $ExportDir" -ForegroundColor Green
Write-Host "   This directory will be used by Docker builds" -ForegroundColor Cyan

