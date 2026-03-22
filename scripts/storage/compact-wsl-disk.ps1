# WSL2 Disk Compaction Script
# This script compacts the WSL2 virtual disk to reclaim space
# Run this from Windows PowerShell (not WSL)

Write-Host "🔍 Checking WSL status..." -ForegroundColor Cyan

# Check if WSL is running
$wslRunning = wsl --list --running 2>$null
if ($wslRunning) {
    Write-Host "⚠️  WSL distributions are running. Shutting down..." -ForegroundColor Yellow
    wsl --shutdown
    Start-Sleep -Seconds 5
    Write-Host "✅ WSL shut down" -ForegroundColor Green
}

# Get WSL distribution name (usually Ubuntu or the default)
Write-Host "`n🔍 Finding WSL distribution..." -ForegroundColor Cyan
$distros = wsl --list --quiet 2>$null
if (-not $distros) {
    Write-Host "❌ No WSL distributions found!" -ForegroundColor Red
    exit 1
}

$defaultDistro = ($distros | Select-Object -First 1).Trim()
Write-Host "Found distribution: $defaultDistro" -ForegroundColor Green

# Find the VHDX file location
Write-Host "`n🔍 Locating WSL virtual disk..." -ForegroundColor Cyan
$vhdxPath = "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu*\LocalState\ext4.vhdx"
$vhdxFiles = Get-ChildItem -Path $env:LOCALAPPDATA\Packages -Recurse -Filter "ext4.vhdx" -ErrorAction SilentlyContinue

if (-not $vhdxFiles) {
    # Try alternative location for Docker Desktop
    $vhdxPath = "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
    if (Test-Path $vhdxPath) {
        $vhdxFiles = @(Get-Item $vhdxPath)
    }
}

if (-not $vhdxFiles) {
    Write-Host "❌ Could not find WSL virtual disk file!" -ForegroundColor Red
    Write-Host "Please run this command manually to find it:" -ForegroundColor Yellow
    Write-Host "Get-ChildItem -Path `$env:LOCALAPPDATA -Recurse -Filter 'ext4.vhdx' -ErrorAction SilentlyContinue" -ForegroundColor Gray
    exit 1
}

foreach ($vhdx in $vhdxFiles) {
    $vhdxPath = $vhdx.FullName
    Write-Host "`n📁 Found virtual disk: $vhdxPath" -ForegroundColor Green
    
    # Get file size before
    $sizeBefore = (Get-Item $vhdxPath).Length / 1GB
    Write-Host "📊 Current size: $([math]::Round($sizeBefore, 2)) GB" -ForegroundColor Cyan
    
    # Optimize the VHDX
    Write-Host "`n🔧 Compacting virtual disk (this may take a few minutes)..." -ForegroundColor Yellow
    Write-Host "   This will free up unused space inside the WSL disk." -ForegroundColor Gray
    
    try {
        # Use Optimize-VHD PowerShell cmdlet (requires Hyper-V)
        if (Get-Command Optimize-VHD -ErrorAction SilentlyContinue) {
            Optimize-VHD -Path $vhdxPath -Mode Full
            Write-Host "✅ Disk optimized using Optimize-VHD" -ForegroundColor Green
        } else {
            # Alternative: Use diskpart
            Write-Host "   Using diskpart method..." -ForegroundColor Gray
            $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
"@
            $diskpartScript | diskpart
            Write-Host "✅ Disk compacted using diskpart" -ForegroundColor Green
        }
        
        # Get file size after
        $sizeAfter = (Get-Item $vhdxPath).Length / 1GB
        $spaceFreed = $sizeBefore - $sizeAfter
        Write-Host "`n📊 New size: $([math]::Round($sizeAfter, 2)) GB" -ForegroundColor Cyan
        Write-Host "💾 Space freed: $([math]::Round($spaceFreed, 2)) GB" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Error compacting disk: $_" -ForegroundColor Red
        Write-Host "`n💡 Alternative method: Use WSL export/import" -ForegroundColor Yellow
        Write-Host "   wsl --export $defaultDistro backup.tar" -ForegroundColor Gray
        Write-Host "   wsl --unregister $defaultDistro" -ForegroundColor Gray
        Write-Host "   wsl --import $defaultDistro . backup.tar" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Done! You can now restart WSL:" -ForegroundColor Green
Write-Host "   wsl" -ForegroundColor Gray

