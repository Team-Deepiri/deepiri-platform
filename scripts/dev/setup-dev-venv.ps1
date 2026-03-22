# Setup development virtual environment one level above deepiri (PowerShell)
# Creates .dev_venv in the parent directory

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ParentDir = Split-Path -Parent $ProjectRoot
$VenvPath = Join-Path $ParentDir ".dev_venv"

Write-Host "🔧 Setting up development virtual environment..." -ForegroundColor Cyan
Write-Host "📍 Location: $VenvPath" -ForegroundColor Yellow

# Check if Python is available
$pythonCmd = "python"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $pythonCmd = "python3"
    } else {
        Write-Host "❌ Error: python or python3 not found. Please install Python 3.11 or later." -ForegroundColor Red
        exit 1
    }
}

# Create venv if it doesn't exist
if (-not (Test-Path $VenvPath)) {
    Write-Host "📦 Creating virtual environment..." -ForegroundColor Cyan
    & $pythonCmd -m venv $VenvPath
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "✅ Virtual environment already exists" -ForegroundColor Green
}

# Activate and upgrade pip
Write-Host "⬆️  Upgrading pip..." -ForegroundColor Cyan
$activateScript = Join-Path $VenvPath "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
    pip install --upgrade pip setuptools wheel
} else {
    Write-Host "⚠️  Warning: Could not activate venv, but continuing..." -ForegroundColor Yellow
    & "$VenvPath\Scripts\python.exe" -m pip install --upgrade pip setuptools wheel
}

# Install development dependencies if requirements.txt exists
$requirementsFile = Join-Path $ProjectRoot "requirements.txt"
if (Test-Path $requirementsFile) {
    Write-Host "📥 Installing development dependencies..." -ForegroundColor Cyan
    if (Test-Path $activateScript) {
        pip install -r $requirementsFile
    } else {
        & "$VenvPath\Scripts\python.exe" -m pip install -r $requirementsFile
    }
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Development environment ready!" -ForegroundColor Green
Write-Host ""
Write-Host "To activate the virtual environment, run:" -ForegroundColor Cyan
Write-Host "  $VenvPath\Scripts\Activate.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or use the activation script:" -ForegroundColor Cyan
Write-Host "  . $ProjectRoot\scripts\activate-dev-venv.ps1" -ForegroundColor Yellow

