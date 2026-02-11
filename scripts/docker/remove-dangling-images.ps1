# Remove Dangling/Untagged Docker Images
# Purpose: Quickly remove all untagged (<none>) Docker images to free up space
# Run this regularly to prevent buildup of dangling images
#
# Usage:
#   1. Open PowerShell (no admin needed)
#   2. Navigate to the deepiri/scripts directory: cd deepiri/scripts
#   3. Run the script: .\remove-dangling-images.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Remove Dangling Docker Images" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is available in WSL
Write-Host "Checking Docker availability..." -ForegroundColor Yellow
try {
    $dockerTest = wsl docker info 2>&1 | Select-String -Pattern "Server Version"
    if ($dockerTest) {
        Write-Host "[OK] Docker is running" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Docker is not accessible" -ForegroundColor Red
        Write-Host "Please ensure Docker is running in WSL" -ForegroundColor Yellow
        Exit 1
    }
} catch {
    Write-Host "[ERROR] Docker is not accessible" -ForegroundColor Red
    Write-Host "Please ensure Docker is running in WSL" -ForegroundColor Yellow
    Exit 1
}

Write-Host ""

# Show current disk usage
Write-Host "Current Docker disk usage:" -ForegroundColor Yellow
wsl docker system df
Write-Host ""

# Get list of dangling images
Write-Host "Finding dangling (untagged) images..." -ForegroundColor Yellow
$danglingImages = wsl docker images -f "dangling=true" -q

if (-not $danglingImages) {
    Write-Host "[OK] No dangling images found!" -ForegroundColor Green
    Write-Host ""
    Exit 0
}

# Count images
$imageCount = ($danglingImages -split "`n" | Where-Object { $_ -and $_.Trim() }).Count
Write-Host "Found $imageCount dangling image(s)" -ForegroundColor Cyan
Write-Host ""

# Ask for confirmation
Write-Host "Do you want to remove these images? (Y/N): " -ForegroundColor Yellow -NoNewline
$confirmation = Read-Host
if ($confirmation -ne "Y" -and $confirmation -ne "y") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    Exit 0
}

Write-Host ""
Write-Host "Removing dangling images..." -ForegroundColor Yellow

# Remove dangling images
$danglingImages -split "`n" | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
    wsl docker rmi $_.Trim() -f 2>&1 | Out-Null
}

Write-Host "[OK] Dangling images removed" -ForegroundColor Green
Write-Host ""

# Show updated disk usage
Write-Host "Updated Docker disk usage:" -ForegroundColor Yellow
wsl docker system df
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: To reclaim space in Windows, run cleanup-and-compact.ps1" -ForegroundColor Cyan
Write-Host ""

