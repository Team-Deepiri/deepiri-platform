# Master script to set up Git hooks for all Deepiri repositories (PowerShell)

Write-Host "🔧 Setting up Git hooks for all Deepiri repositories..." -ForegroundColor Cyan
Write-Host ""

$REPO_ROOT = if (Get-Command git -ErrorAction SilentlyContinue) {
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) { $root } else { $PWD }
} else {
    $PWD
}

Set-Location $REPO_ROOT

# Function to setup hooks in a directory
function Setup-Hooks {
    param(
        [string]$RepoPath,
        [string]$RepoName
    )
    
    if ((Test-Path $RepoPath) -and (Test-Path "$RepoPath/.git-hooks/pre-push")) {
        Write-Host "📦 Setting up hooks for $RepoName..." -ForegroundColor Yellow
        Push-Location $RepoPath
        if (Test-Path "setup-hooks.sh") {
            git config core.hooksPath .git-hooks
            Write-Host "✔ Hooks configured for $RepoName" -ForegroundColor Green
        } else {
            git config core.hooksPath .git-hooks
            Write-Host "✔ Hooks configured for $RepoName" -ForegroundColor Green
        }
        Pop-Location
    } else {
        Write-Host "⚠️  Skipping $RepoName (not found or hooks not present)" -ForegroundColor Yellow
    }
}

# Setup hooks for main repo (deepiri-platform)
Write-Host "🏠 Setting up hooks for main repository (deepiri-platform)..." -ForegroundColor Cyan
if (Test-Path ".git-hooks/pre-push") {
    git config core.hooksPath .git-hooks
    Write-Host "✔ Main repository hooks configured" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: Main repository hooks not found" -ForegroundColor Yellow
}
Write-Host ""

# Setup hooks for all submodules
Write-Host "📚 Setting up hooks for submodules..." -ForegroundColor Cyan
Setup-Hooks "deepiri-core-api" "deepiri-core-api"
Setup-Hooks "deepiri-web-frontend" "deepiri-web-frontend"
Setup-Hooks "platform-services/backend/deepiri-api-gateway" "deepiri-api-gateway"
Setup-Hooks "platform-services/backend/deepiri-auth-service" "deepiri-auth-service"
Setup-Hooks "platform-services/backend/deepiri-external-bridge-service" "deepiri-external-bridge-service"
Setup-Hooks "diri-cyrex" "diri-cyrex"

Write-Host ""
Write-Host "✅ Git hooks setup complete for all repositories!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Note: If you're working in a submodule, you may need to:" -ForegroundColor Cyan
Write-Host "   1. cd into the submodule directory"
Write-Host "   2. Run: git config core.hooksPath .git-hooks"
Write-Host "   3. Or run: ./setup-hooks.sh (if using Git Bash)"

