# Activate the development virtual environment (PowerShell)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ParentDir = Split-Path -Parent $ProjectRoot
$VenvPath = Join-Path $ParentDir ".dev_venv"

if (-not (Test-Path $VenvPath)) {
    Write-Host "❌ Virtual environment not found at $VenvPath" -ForegroundColor Red
    Write-Host "💡 Run .\scripts\setup-dev-venv.ps1 to create it" -ForegroundColor Yellow
    exit 1
}

$activateScript = Join-Path $VenvPath "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
    Write-Host "✅ Activated virtual environment: $VenvPath" -ForegroundColor Green
} else {
    Write-Host "❌ Activation script not found at $activateScript" -ForegroundColor Red
    exit 1
}

