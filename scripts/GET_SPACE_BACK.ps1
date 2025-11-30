# COMPACT WSL2 VHDX - Get Your Disk Space Back
# Run this as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Compacting WSL2 VHDX to Reclaim Space" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and 'Run as Administrator'" -ForegroundColor Yellow
    Exit 1
}

# Find VHDX
$vhdxPath = "C:\Users\josep\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx"

if (-not (Test-Path $vhdxPath)) {
    Write-Host "ERROR: VHDX not found at $vhdxPath" -ForegroundColor Red
    Exit 1
}

# Show size before
$sizeBefore = (Get-Item $vhdxPath).Length / 1GB
Write-Host "VHDX Size Before: $([math]::Round($sizeBefore, 2)) GB" -ForegroundColor Cyan
Write-Host ""

# Shutdown WSL
Write-Host "Shutting down WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 5

# Compact
Write-Host "Compacting VHDX (this takes 2-5 minutes)..." -ForegroundColor Yellow
try {
    Optimize-VHD -Path $vhdxPath -Mode Full
    Write-Host "SUCCESS!" -ForegroundColor Green
} catch {
    Write-Host "Optimize-VHD failed, trying DiskPart..." -ForegroundColor Yellow
    
    $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $diskpartScript -Encoding ASCII
    diskpart /s $tempFile | Out-Null
    Remove-Item $tempFile
    Write-Host "SUCCESS!" -ForegroundColor Green
}

Start-Sleep -Seconds 2

# Show size after
$sizeAfter = (Get-Item $vhdxPath).Length / 1GB
$reclaimed = [math]::Round($sizeBefore - $sizeAfter, 2)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "VHDX Size After: $([math]::Round($sizeAfter, 2)) GB" -ForegroundColor Cyan
Write-Host "Space Reclaimed: $reclaimed GB" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Done! WSL is shut down." -ForegroundColor Green
Write-Host "Start it again with: wsl" -ForegroundColor Yellow
Write-Host ""

